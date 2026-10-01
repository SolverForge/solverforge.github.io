#!/usr/bin/env ruby
# frozen_string_literal: true

# Read existing publishable DWH results; never execute benchmark workloads.
require "json"
require "open3"
require "optparse"
require "fileutils"

module BenchmarkImport
  ROOT = File.expand_path("..", __dir__)

  QUERY = <<~SQL.freeze

    BEGIN TRANSACTION ISOLATION LEVEL REPEATABLE READ READ ONLY;
    SET LOCAL TIME ZONE 'UTC';
    SET LOCAL statement_timeout = '60s';
    SET LOCAL jit = off;
    SET LOCAL enable_nestloop = off;
    WITH selected AS MATERIALIZED (
      SELECT DISTINCT ON (benchmark_name)
        id, benchmark_name, completed_at, run_kind, nightly, result_count,
        git_commit, git_dirty, solvers, time_limits_seconds
      FROM publishable_benchmark_runs r
      WHERE run_kind = 'candidate' AND nightly IS TRUE
        AND EXISTS (SELECT 1 FROM publishable_benchmark_result_facts f WHERE f.run_id = r.id)
        AND NOT EXISTS (SELECT 1 FROM publishable_benchmark_result_facts f
          WHERE f.run_id = r.id AND f.dataset_set IS DISTINCT FROM 'canonical')
      ORDER BY benchmark_name, completed_at DESC, id DESC
    )
    SELECT json_build_object(
      'source', 'publishable_benchmark_result_facts',
      'selection', 'Latest publishable full canonical nightly candidate run per problem, by completed_at',
      'runs', (SELECT json_agg(selected ORDER BY benchmark_name) FROM selected),
      'results', (SELECT json_agg(row_to_json(public_result) ORDER BY benchmark_name, instance, time_limit_seconds, solver)
        FROM (
          SELECT f.run_id, f.benchmark_name, f.dataset, f.dataset_set, f.instance,
            f.solver, f.solver_version, f.time_limit_seconds, f.hard_feasible,
            f.cost, f.reference_cost, f.quality_ratio, f.actual_time_seconds,
            f.wall_time_over_limit, f.watchdog_killed,
            (NULLIF(f.run_error, '') IS NOT NULL OR NULLIF(f.validation_error, '') IS NOT NULL) AS error
          FROM publishable_benchmark_result_facts f JOIN selected s ON s.id = f.run_id
        ) public_result),
      'references', (SELECT json_agg(row_to_json(reference_catalog) ORDER BY benchmark_name, instance)
        FROM (
          SELECT c.benchmark_name, c.dataset, c.instance, c.reference_cost, c.reference_kind,
                 c.source_name, c.source_revision
          FROM benchmark_reference_catalog c
          WHERE c.benchmark_name IN (SELECT benchmark_name FROM selected)
        ) reference_catalog)
    );
    COMMIT;
  SQL

  LABELS = {
    "cvrp" => ["Capacitated vehicle routing", "Assign customers to vehicle routes while respecting capacity. Lower route cost is better."],
    "employee-scheduling" => ["Employee scheduling", "Assign nurses to shifts while respecting hard rules. Among feasible schedules, lower penalty cost is better."],
    "job-shop-scheduling" => ["Job-shop scheduling", "Sequence jobs on machines while respecting operation order and machine capacity. Lower makespan is better."]
  }.freeze

  module_function

  # Gate progression records observed feasibility, not process duration.
  def rank_solvers(summaries, solver_order, budget = nil)
    budget ||= summaries.map { |row| row.fetch("budget") }.max
    rows = summaries.select { |row| row.fetch("budget") == budget }.to_h { |row| [row.fetch("solver"), row] }
    earlier = summaries.map { |row| row.fetch("budget") }.select { |gate| gate < budget }.uniq.sort
    by_gate = summaries.to_h { |row| [[row.fetch("solver"), row.fetch("budget")], row] }
    solver_order.sort_by do |solver|
      row = rows.fetch(solver)
      [row.fetch("total") - row.fetch("feasible"),
       earlier.map { |gate| -by_gate.fetch([solver, gate]).fetch("feasible") },
       row.fetch("gap_percent") || Float::INFINITY,
       row.fetch("mean_cost") || Float::INFINITY, solver]
    end
  end

  def summarize(snapshot)
    runs = snapshot["runs"] || []
    results = snapshot["results"] || []
    raise ArgumentError, "No publishable warehouse results" if runs.empty? || results.empty?
    unless runs.map { |run| run.fetch("benchmark_name") }.uniq.length == runs.length
      raise ArgumentError, "Expected one selected run per problem"
    end

    problems = runs.map do |run|
      rows = results.select { |row| row.fetch("run_id") == run.fetch("id") }
      unless run.fetch("run_kind") == "candidate" && run.fetch("nightly") == true && rows.all? { |row| row.fetch("dataset_set") == "canonical" }
        raise ArgumentError, "Only full canonical nightly candidate runs may be published"
      end
      unless rows.length == run.fetch("result_count")
        raise ArgumentError, "Incomplete result snapshot for #{run.fetch('benchmark_name')}"
      end
      keys = rows.map { |row| [row.fetch("instance"), row.fetch("solver"), row.fetch("time_limit_seconds")] }.uniq
      run_instances = rows.map { |row| row.fetch("instance") }.uniq
      expected = run_instances.length * run.fetch("solvers").length * run.fetch("time_limits_seconds").length
      unless keys.length == rows.length && rows.length == expected
        raise ArgumentError, "Incomplete or duplicated comparison matrix"
      end
      groups = rows.group_by { |row| [row.fetch("time_limit_seconds"), row.fetch("solver"), row.fetch("solver_version")] }
      summaries = groups.sort.map do |(budget, solver, version), group|
        feasible = group.select { |row| row.fetch("hard_feasible") == true }
        ratios = feasible.map { |row| row.fetch("quality_ratio") }.compact
        costs = feasible.map { |row| row.fetch("cost") }.compact
        times = group.map { |row| row.fetch("actual_time_seconds") }.compact
        feasible_times = feasible.map { |row| row.fetch("actual_time_seconds") }.compact
        # Float division matters even for integer-valued JSON costs.
        {
          "budget" => budget, "solver" => solver, "version" => version, "total" => group.length,
          "feasible" => feasible.length, "quality_samples" => ratios.length, "cost_samples" => costs.length,
          "feasible_time_samples" => feasible_times.length,
          "gap_percent" => ratios.empty? ? nil : 100 * (ratios.sum / ratios.length.to_f - 1),
          "mean_cost" => costs.empty? ? nil : costs.sum / costs.length.to_f,
          "mean_seconds" => times.empty? ? nil : times.sum / times.length.to_f,
          "mean_feasible_seconds" => feasible_times.empty? ? nil : feasible_times.sum / feasible_times.length.to_f,
          "errors" => group.count { |row| row.fetch("error") == true },
          "over_budget" => group.count { |row| row.fetch("wall_time_over_limit") == true }
        }
      end
      name = run.fetch("benchmark_name")
      title, description = LABELS.fetch(name) { [name.tr("-", " ").capitalize, "Lower validated cost is better; feasibility comes first."] }
      problem_references = (snapshot["references"] || []).select { |row| row.fetch("benchmark_name") == name }
      kinds = problem_references.map { |row| row.fetch("reference_kind") }.uniq.sort
      sources = problem_references.map { |row| [row.fetch("source_name"), row.fetch("source_revision")] }.uniq.sort
      reference_instances = problem_references.map { |row| row.fetch("instance") }.uniq
      covered_run_instances = reference_instances & run_instances
      first_feasible_gates = run.fetch("solvers").to_h do |solver|
        earliest = {}
        rows.each do |row|
          next unless row.fetch("solver") == solver && row.fetch("hard_feasible") == true

          instance = row.fetch("instance")
          earliest[instance] = [earliest.fetch(instance, Float::INFINITY), row.fetch("time_limit_seconds")].min
        end
        [solver, {
          "counts" => run.fetch("time_limits_seconds").sort.to_h { |gate| [gate.to_s, earliest.values.count(gate)] },
          "never" => run_instances.length - earliest.length
        }]
      end
      { "first_feasible_gates" => first_feasible_gates }.merge(run.reject { |key, _| key == "solvers" }).merge(
        "title" => title, "description" => description,
        "instances" => run_instances.length,
        "datasets" => rows.map { |row| row.fetch("dataset") }.uniq.sort,
        "dataset_sets" => rows.map { |row| row.fetch("dataset_set") }.uniq.sort,
        "summaries" => summaries,
        "solvers" => rank_solvers(summaries, run.fetch("solvers")),
        "solver_orders" => run.fetch("time_limits_seconds").to_h { |budget| [budget.to_s, rank_solvers(summaries, run.fetch("solvers"), budget)] },
        "reference_present" => !problem_references.empty?,
        "reference_instances" => reference_instances.length,
        "reference_covered_run_instances" => covered_run_instances.length,
        "reference_covers_run" => !run_instances.empty? && covered_run_instances.length == run_instances.length,
        "reference_kinds" => kinds,
        "reference_sources" => sources.map { |source, revision| { "name" => source, "revision" => revision } }
      )
    end
    unless problems.sum { |problem| problem.fetch("result_count") } == results.length
      raise ArgumentError, "Unexpected rows outside selected runs"
    end
    names = problems.map { |problem| problem.fetch("benchmark_name") }
    {
      "source" => snapshot.fetch("source"), "selection" => snapshot.fetch("selection"), "problems" => problems,
      "unavailable" => LABELS.filter_map { |name, details| { "id" => name, "title" => details[0] } unless names.include?(name) }
    }
  end
  def main(argv = ARGV)
    options = {
      database_url: ENV.fetch("BENCH_DATABASE_URL", "postgresql://postgres@localhost/solverforge_bench"),
      summary_output: File.join(ROOT, "src/_data/benchmarks.json"),
      results_output: File.join(ROOT, "src/benchmarks/results.json"),
      summary_only: false
    }
    parser = OptionParser.new do |opts|
      opts.banner = "Usage: ruby scripts/import-benchmarks.rb [options]"
      opts.separator "Read existing publishable DWH results; never execute benchmark workloads."
      opts.on("--database-url URL", "Database URL (default: BENCH_DATABASE_URL or local solverforge_bench)") { |value| options[:database_url] = value }
      opts.on("--snapshot PATH", "Read an existing JSON snapshot offline; do not contact the warehouse") { |value| options[:snapshot] = value }
      opts.on("--summary-only", "Offline mode: regenerate the summary without rewriting evidence (requires --snapshot)") { options[:summary_only] = true }
      opts.on("--summary-output PATH", "Summary destination (default: src/_data/benchmarks.json)") { |value| options[:summary_output] = value }
      opts.on("--results-output PATH", "Evidence destination (default: src/benchmarks/results.json)") { |value| options[:results_output] = value }
      opts.on("-h", "--help", "Show this help") { options[:help] = true }
    end
    remaining = parser.parse(argv.dup)
    if options[:help]
      puts parser
      return 0
    end
    unless remaining.empty?
      warn "Benchmark import failed: unexpected positional arguments. Use --help."
      return 2
    end
    if options[:summary_only] && !options[:snapshot]
      warn "Benchmark import failed: --summary-only requires --snapshot."
      return 2
    end

    if options[:snapshot]
      snapshot = JSON.parse(File.read(options[:snapshot]))
    else
      response, _stderr, status = Open3.capture3(
        "psql", options[:database_url], "-X", "-qAt", "-v", "ON_ERROR_STOP=1",
        stdin_data: QUERY
      )
      unless status.success?
        # Never relay psql stderr or its arguments: they may contain credentials.
        warn "Benchmark import failed: read-only warehouse query failed. Check database access and publication views."
        return 1
      end
      snapshot = JSON.parse(response)
    end
    summary = summarize(snapshot)
    outputs = [[options[:summary_output], summary]]
    outputs << [options[:results_output], snapshot] unless options[:summary_only]
    # Validate JSON serialization before changing either destination.
    serialized = outputs.map { |path, data| [path, JSON.pretty_generate(data, allow_nan: false) + "\n"] }
    serialized.each do |path, data|
      FileUtils.mkdir_p(File.dirname(path))
      File.write(path, data)
    end
    puts "Imported #{summary.fetch('problems').length} problems, #{snapshot.fetch('results').length} existing results. No benchmarks executed."
    0
  rescue OptionParser::ParseError
    # An invalid argument can itself be a secret; omit the parser's raw message.
    warn "Benchmark import failed: invalid command-line options. Use --help."
    2
  rescue JSON::ParserError, JSON::GeneratorError
    warn "Benchmark import failed: invalid snapshot JSON or non-finite summary numbers."
    1
  rescue SystemCallError, IOError
    warn "Benchmark import failed: unable to access input/output files or execute psql."
    1
  rescue StandardError
    warn "Benchmark import failed: snapshot validation or summarization failed."
    1
  end
end

exit BenchmarkImport.main if $PROGRAM_NAME == __FILE__
