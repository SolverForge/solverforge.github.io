#!/usr/bin/env ruby
# frozen_string_literal: true

# Verify checked-in evidence offline; never query or run benchmarks.
require "json"
require "yaml"
require "open3"
require "tmpdir"
require_relative "import-benchmarks"

class BenchmarkSnapshotTest
  ROOT = File.expand_path("..", __dir__)
  TOLERANCE = 1e-9

  def initialize
    @snapshot = JSON.parse(File.read(File.join(ROOT, "src/benchmarks/results.json")))
    @summary = JSON.parse(File.read(File.join(ROOT, "src/_data/benchmarks.json")))
    @assertions = 0
  end

  attr_reader :assertions

  def assert(condition, message = "assertion failed")
    @assertions += 1
    raise message unless condition
  end

  def assert_equal(expected, actual)
    assert(expected == actual, "expected #{expected.inspect}, got #{actual.inspect}")
  end

  def assert_raises(type)
    @assertions += 1
    begin
      yield
    rescue type
      return
    end
    raise "expected #{type}"
  end

  def copy(value)
    Marshal.load(Marshal.dump(value))
  end

  def equivalent(left, right, path = "")
    case left
    when Hash
      assert(right.is_a?(Hash), "#{path}: expected hash")
      assert_equal(left.keys.sort, right.keys.sort)
      left.sum { |key, value| equivalent(value, right.fetch(key), "#{path}.#{key}") }
    when Array
      assert(right.is_a?(Array), "#{path}: expected array")
      assert_equal(left.length, right.length)
      left.each_with_index.sum { |value, index| equivalent(value, right[index], "#{path}[#{index}]") }
    when Numeric
      assert(right.is_a?(Numeric) && (left - right).abs <= TOLERANCE, "#{path}: numeric drift")
      1
    else
      assert_equal(left, right)
      1
    end
  end

  def test_summary_matches_recorded_evidence
    equivalent(BenchmarkImport.summarize(@snapshot), @summary)
  end

  def test_gate_quality_beats_early_process_exit
    rows = [
      { "budget" => 1, "solver" => "quick", "total" => 10, "feasible" => 10,
        "mean_feasible_seconds" => 0.1, "gap_percent" => 20, "mean_cost" => 120 },
      { "budget" => 1, "solver" => "better", "total" => 10, "feasible" => 10,
        "mean_feasible_seconds" => 1.0, "gap_percent" => 2, "mean_cost" => 102 }
    ]
    assert_equal(%w[better quick], BenchmarkImport.rank_solvers(rows, %w[quick better], 1))
  end

  def test_earlier_feasibility_beats_later_quality
    rows = [[1, "early", 10, 20], [1, "late", 0, 100],
            [10, "early", 10, 20], [10, "late", 10, 1]].map do |gate, solver, feasible, gap|
      { "budget" => gate, "solver" => solver, "total" => 10, "feasible" => feasible,
        "mean_feasible_seconds" => 1, "gap_percent" => gap, "mean_cost" => 100 + gap }
    end
    assert_equal(%w[early late], BenchmarkImport.rank_solvers(rows, %w[late early], 10))
  end

  def test_each_budget_ranks_feasibility_then_earlier_gates_then_quality
    @summary.fetch("problems").each do |problem|
      next if problem.key?("scale")

      problem.fetch("time_limits_seconds").each do |budget|
        rows = problem.fetch("summaries").select { |row| row.fetch("budget") == budget }
        expected = rows.sort_by do |row|
          earlier = problem.fetch("time_limits_seconds").sort.filter_map do |gate|
            next if gate >= budget
            previous = problem.fetch("summaries").find do |value|
              value.fetch("solver") == row.fetch("solver") && value.fetch("budget") == gate
            end
            -previous.fetch("feasible")
          end
          [row.fetch("total") - row.fetch("feasible"), earlier,
           row["gap_percent"] || Float::INFINITY, row["mean_cost"] || Float::INFINITY,
           row.fetch("solver")]
        end.map { |row| row.fetch("solver") }
        assert_equal(expected, problem.fetch("solver_orders").fetch(budget.to_s))
        assert_equal(expected, problem.fetch("solvers")) if budget == problem.fetch("time_limits_seconds").max
      end
    end
  end

  # Recomputed from the raw score strings, not through the importer's parser.
  # A solver that returned no plan has no score and ranks after every scored
  # solver; a feasible plan's score is its validator cost.
  def test_large_scale_problems_rank_by_score
    scale = @summary.fetch("problems").select { |problem| problem.key?("scale") }
    huge = @snapshot.fetch("runs").select { |run| run["benchmark_category"] == "huge_scale" }
    assert_equal(huge.map { |run| run.fetch("benchmark_name") }.sort, scale.map { |problem| problem.fetch("benchmark_name") }.sort)
    scale.each do |problem|
      outcomes = @snapshot.fetch("scale_outcomes").select { |row| row.fetch("run_id") == problem.fetch("id") }
      assert_equal(problem.fetch("result_count"), outcomes.length)
      parse = ->(score) { score && score.split("/").map { |part| -part.to_i } }
      totals = outcomes.group_by { |row| row.fetch("solver") }.transform_values do |rows|
        parts = rows.map { |row| parse.call(row["score"]) }
        parts.all? ? [parts.sum(&:first), parts.sum(&:last)] : [Float::INFINITY, Float::INFINITY]
      end
      expected = totals.sort_by { |solver, (hard, soft)| [hard, soft, solver] }.map(&:first)
      outcomes.each do |outcome|
        result = @snapshot.fetch("results").find do |row|
          row.fetch("run_id") == outcome.fetch("run_id") && row.fetch("instance") == outcome.fetch("instance") && row.fetch("solver") == outcome.fetch("solver")
        end
        next unless result.fetch("hard_feasible") == true

        assert_equal([0, result.fetch("cost").to_i], parse.call(outcome.fetch("score")))
      end
      assert_equal(expected, problem.fetch("solvers"))
      problem.fetch("scale").fetch("instances").each do |instance|
        rows = instance.fetch("rows")
        assert_equal(problem.fetch("solvers").length, rows.length)
        rows.each do |row|
          raw = outcomes.find { |outcome| outcome.fetch("instance") == instance.fetch("instance") && outcome.fetch("solver") == row.fetch("solver") }
          hard, soft = parse.call(raw["score"])
          assert_equal([hard, soft], [row["hard_violations"], row["soft_cost"]])
          native = raw.fetch("native")
          assert_equal(native.fetch("shifts") - native.fetch("unassigned_shifts"), row.fetch("assigned")) if native.key?("unassigned_shifts")
        end
      end
    end
  end

  def test_missing_large_scale_outcome_rejected
    changed = copy(@snapshot)
    assert(!changed.fetch("scale_outcomes").empty?, "expected large-scale outcomes in the snapshot")
    changed.fetch("scale_outcomes").pop
    assert_raises(ArgumentError) { BenchmarkImport.summarize(changed) }
  end

  def test_process_duration_does_not_change_rank
    changed = copy(@snapshot)
    changed.fetch("results").each { |row| row["actual_time_seconds"] = row["solver"] == "vroom" ? 0.001 : 999 }
    BenchmarkImport.summarize(changed).fetch("problems").zip(@summary.fetch("problems")).each do |updated, original|
      assert_equal(original.fetch("solver_orders"), updated.fetch("solver_orders"))
    end
  end

  def test_first_feasible_gates_are_observations_not_runtimes
    BenchmarkImport.summarize(@snapshot).fetch("problems").each do |problem|
      raw = @snapshot.fetch("results").select { |row| row["benchmark_name"] == problem["benchmark_name"] }
      problem.fetch("solvers").each do |solver|
        earliest = {}
        raw.each do |row|
          next unless row["solver"] == solver && row["hard_feasible"] == true
          instance = row.fetch("instance")
          earliest[instance] = [earliest.fetch(instance, Float::INFINITY), row.fetch("time_limit_seconds")].min
        end
        expected = problem.fetch("time_limits_seconds").to_h do |gate|
          [gate.to_s, earliest.values.count(gate)]
        end
        observed = problem.fetch("first_feasible_gates").fetch(solver)
        assert_equal(expected, observed.fetch("counts"))
        assert_equal(problem.fetch("instances") - earliest.length, observed.fetch("never"))
      end
    end
  end

  def test_versions_are_present
    @snapshot.fetch("results").each do |row|
      assert(!row.fetch("solver_version").to_s.empty?)
      assert(row.fetch("time_limit_seconds").positive?)
    end
  end

  def test_only_full_runs
    @snapshot.fetch("runs").each do |run|
      assert_equal("candidate", run.fetch("run_kind"))
      assert_equal(false, run.fetch("git_dirty"))
    end
    assert(@snapshot.fetch("results").all? { |row| row.fetch("dataset_set") == "canonical" })
  end

  def test_every_published_solver_is_named
    names = YAML.safe_load_file(File.join(BenchmarkImport::ROOT, "src/_data/benchmark_solvers.yml"))
    @summary.fetch("problems").flat_map { |problem| problem.fetch("solvers") }.uniq.each do |solver|
      assert(names.key?(solver), "#{solver} has no entry in src/_data/benchmark_solvers.yml")
      entry = names.fetch(solver, {})
      assert(!entry["name"].to_s.empty?, "#{solver} has no display name")
      assert(entry["url"].to_s.start_with?("https://"), "#{solver} has no project link")
    end
  end

  def test_published_problems_have_hand_written_copy
    assert(!@summary.fetch("problems").empty?)
    @summary.fetch("problems").each do |problem|
      title, description = BenchmarkImport::LABELS.fetch(problem.fetch("benchmark_name"))
      assert_equal(title, problem.fetch("title"))
      assert_equal(description, problem.fetch("description"))
    end
  end

  def test_partial_snapshot_rejected
    changed = copy(@snapshot)
    changed.fetch("results").pop
    assert_raises(ArgumentError) { BenchmarkImport.summarize(changed) }
  end

  def test_quick_run_rejected
    changed = copy(@snapshot)
    changed.fetch("runs").first["run_kind"] = "quick"
    assert_raises(ArgumentError) { BenchmarkImport.summarize(changed) }
  end

  def test_custom_dataset_rejected
    changed = copy(@snapshot)
    changed.fetch("results").first["dataset_set"] = "custom"
    assert_raises(ArgumentError) { BenchmarkImport.summarize(changed) }
  end

  def test_duplicate_result_rejected
    changed = copy(@snapshot)
    changed.fetch("results")[1] = copy(changed.fetch("results").first)
    assert_raises(ArgumentError) { BenchmarkImport.summarize(changed) }
  end

  def test_infeasible_quality_not_averaged
    changed = copy(@snapshot)
    changed.fetch("results").find { |row| row.fetch("hard_feasible") == false }["quality_ratio"] = 999999
    equivalent(BenchmarkImport.summarize(changed), @summary)
  end

  def test_comparison_walks_whole_summary
    assert(equivalent(BenchmarkImport.summarize(@snapshot), @summary) > 100)
  end

  def test_numeric_drift_beyond_tolerance_is_rejected
    changed = copy(@summary)
    row = changed.fetch("problems").flat_map { |problem| problem.fetch("summaries") }
      .find { |summary| summary["gap_percent"].is_a?(Numeric) }
    assert(!row.nil?, "expected a measured reference gap in the snapshot")
    row["gap_percent"] += 1e-4
    assert_raises(RuntimeError) { equivalent(BenchmarkImport.summarize(@snapshot), changed) }
  end

  def numeric_drift(left, right)
    case left
    when Hash
      left.flat_map { |key, value| numeric_drift(value, right.fetch(key)) }
    when Array
      left.each_with_index.flat_map { |value, index| numeric_drift(value, right.fetch(index)) }
    when Numeric
      [(left - right).abs / [left.abs, 1.0].max]
    else
      []
    end
  end

  def test_recorded_drift_is_only_floating_point_noise
    assert(numeric_drift(BenchmarkImport.summarize(@snapshot), @summary).max < 1e-12)
  end

  def test_cli_rebuilds_from_existing_evidence_without_database
    Dir.mktmpdir("benchmark-ruby-") do |directory|
      summary_path = File.join(directory, "summary.json")
      evidence_path = File.join(ROOT, "src/benchmarks/results.json")
      original = File.binread(evidence_path)
      stdout, stderr, status = Open3.capture3(
        { "BENCH_DATABASE_URL" => "invalid://offline-must-not-connect" },
        RbConfig.ruby, File.join(ROOT, "scripts/import-benchmarks.rb"),
        "--snapshot", evidence_path, "--summary-only", "--summary-output", summary_path
      )
      assert(status.success?, "offline import failed: #{stderr}")
      assert(stdout.include?("No benchmarks executed"))
      equivalent(@summary, JSON.parse(File.read(summary_path)))
      assert_equal(original, File.binread(evidence_path))
    end
  end

  def test_read_only_psql_transport
    Dir.mktmpdir("benchmark-psql-") do |directory|
      fake = File.join(directory, "psql")
      capture = File.join(directory, "request.json")
      summary_path = File.join(directory, "summary.json")
      results_path = File.join(directory, "results.json")
      File.write(fake, <<~RUBY)
        #!#{RbConfig.ruby}
        require "json"
        File.write(ENV.fetch("BENCH_REQUEST"), JSON.generate({ "argv" => ARGV, "query" => STDIN.read }))
        STDOUT.write(File.read(ENV.fetch("BENCH_EVIDENCE")))
      RUBY
      File.chmod(0o755, fake)
      stdout, stderr, status = Open3.capture3(
        { "PATH" => "#{directory}:#{ENV.fetch('PATH')}", "BENCH_REQUEST" => capture,
          "BENCH_EVIDENCE" => File.join(ROOT, "src/benchmarks/results.json") },
        RbConfig.ruby, File.join(ROOT, "scripts/import-benchmarks.rb"),
        "--database-url", "postgresql://fixture.invalid/db?application_name=space value",
        "--summary-output", summary_path, "--results-output", results_path
      )
      assert(status.success?, "psql transport failed: #{stderr}")
      request = JSON.parse(File.read(capture))
      assert_equal(["postgresql://fixture.invalid/db?application_name=space value", "-X", "-qAt", "-v", "ON_ERROR_STOP=1"], request.fetch("argv"))
      assert_equal(BenchmarkImport::QUERY, request.fetch("query"))
      assert(request.fetch("query").include?("REPEATABLE READ READ ONLY"))
      assert(request.fetch("query").include?("statement_timeout = '60s'"))
      equivalent(@summary, JSON.parse(File.read(summary_path)))
      assert_equal(@snapshot, JSON.parse(File.read(results_path)))
      assert(stdout.include?("No benchmarks executed"))
    end
  end

  def test_site_has_no_python_tooling
    assert(Dir.glob(File.join(ROOT, "scripts/**/*.py")).empty?, "Python scripts remain")
    assert(!File.read(File.join(ROOT, "Makefile")).include?("python3"), "Makefile still requires Python")
    # CI provides python3.14 only as the subject of the Python docs gate
    # (scripts/verify-python-docs.rb, Ruby); no site step may run Python itself.
    workflow = File.read(File.join(ROOT, ".github/workflows/site.yml"))
    run_lines = workflow.lines.grep(/\A\s*(run:|[^:#]*$)/).join
    assert(!run_lines.match?(/\b(python3?(\.\d+)?|pip3?)\s/), "CI runs Python directly")
  end
end

if $PROGRAM_NAME == __FILE__
  test = BenchmarkSnapshotTest.new
  methods = test.public_methods.grep(/^test_/).sort
  abort "No benchmark checks ran" if methods.empty?
  failures = methods.filter_map do |method|
    test.public_send(method)
    nil
  rescue StandardError => error
    "#{method}: #{error.message}"
  end
  puts "#{methods.length} benchmark tests, #{test.assertions} assertions, #{failures.length} failures"
  failures.each { |failure| warn failure }
  exit(failures.empty? ? 0 : 1)
end
