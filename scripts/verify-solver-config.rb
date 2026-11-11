#!/usr/bin/env ruby
# frozen_string_literal: true

# Holds the solver docs to what crates.io solverforge 0.26.1 does.
#
# Every ```toml block on the solver pages is parsed with
# `SolverConfig::from_toml_str` by the fixture crate in
# scripts/fixtures/solver-config (solverforge = "=0.26.1"), then solved on a
# fixed model that owns the variables the block names, so a missing field, a
# repeated key, an unknown key, or a variable name the model does not have
# fails here. Every ```rust block on those pages must be verbatim in the
# fixture, and the fixture runs each page's lifecycle snippets with the
# outcomes the page states asserted. Nothing skips: a missing tool, build, or
# block is a failure.
#
#   ruby scripts/verify-solver-config.rb            # static + live
#   ruby scripts/verify-solver-config.rb --static   # page/fixture contract only
#
# A block that is meant to fail carries a marker on the line before its fence:
#
#   <!-- sf-toml: expect="parse-error" message="unknown field `seconds_spent_limt`" -->
#   <!-- sf-toml: expect="solve-error" message="..." -->
#
# and must fail at that stage with that text.
#
# The live half needs cargo. SOLVER_CONFIG_TARGET_DIR overrides the cargo
# target directory (CI caches it).

require "fileutils"
require "open3"
require "tmpdir"

SITE_ROOT = File.expand_path("..", __dir__)
FIXTURE = File.join(SITE_ROOT, "scripts/fixtures/solver-config")
PAGES = (Dir.glob(File.join(SITE_ROOT, "src/docs/solverforge/solver/*.md")).sort +
  [File.join(SITE_ROOT, "src/reference/lifecycle-pause-resume-contract.md")]).freeze
EXPECTED_PAGE_COUNT = 12

# Scenario name => [what it runs, lines its output must contain]. Each
# scenario asserts inside the fixture and prints "SCENARIO <name> OK" last.
SCENARIOS = {
  "index" => ["Solver overview quick start: solve, stream events, delete",
              ["finished with reason Some(TerminatedByConfig)"]],
  "configuration" => ["SolverConfig parsing, builders, solver_toml, and the config callback", []],
  "config-load" => ["SolverConfig::load reads the page's example solver.toml from the working directory", []],
  "cwd-ignored" => ["a solver.toml in the working directory is not read by a retained solve", []],
  "termination" => ["time limits add up, no hidden time limit, omitted phases, cancel",
                    ["minutes 1 + seconds 30 -> Some(90.0) s (time_or_step_count)"]],
  "solver-manager" => ["events, status, pause -> Paused -> resume, problem change, snapshots, analysis, cancel, delete",
                       ["completed with reason Some(TerminatedByConfig)", "paused at snapshot Some("]]
}.freeze

# Blocks the fixture cannot solve because the page names a model capability it
# does not define. They are still parsed. Matched against the block text.
PARSE_ONLY = [
  [/group_name = "task_operator_assignment"/, "candidate-backed scalar group: needs the model's own ScalarGroup candidate provider"],
  [/conflict_repair_move_selector/, "conflict repair: needs a model-registered repair provider"],
  [/type = "custom"/, "custom phase: compiled in through #[planning_solution(search = ...)]"],
  [/type = "partitioned_search"/, "partitioned search: needs a compiled SolutionPartitioner"],
  [/selection_metric = /, "sorted/probabilistic order: needs a registered candidate metric"]
].freeze

Block = Struct.new(:page, :line, :text, :expect, :message, :model, :reason, :wrapped, keyword_init: true) do
  def where = "#{page}:#{line}"
end

def log(message)
  puts "[verify-solver-config] #{message}"
end

def fail!(message)
  warn "[verify-solver-config] ERROR: #{message}"
  exit 1
end

def rel(path) = path.delete_prefix("#{SITE_ROOT}/")

def read(path)
  fail!("missing file: #{rel(path)}") unless File.file?(path)
  File.read(path)
end

# Fenced blocks of one language with their 1-based fence line and the line
# before the fence.
def fences(text, language)
  blocks = []
  lines = text.lines
  index = 0
  while index < lines.length
    if lines[index].rstrip == "```#{language}"
      start = index
      body = []
      index += 1
      index += 1 while index < lines.length && (body << lines[index]) && lines[index].rstrip != "```"
      fail!("unterminated ```#{language} fence at line #{start + 1}") if index >= lines.length
      body.pop
      blocks << { line: start + 1, text: body.join, before: start.positive? ? lines[start - 1] : "" }
    end
    index += 1
  end
  blocks
end

def model_for(text)
  return "grouped" if text.include?('"required_shift_assignment"')
  return "operations" if text.match?(/variable_name = "operations"/)
  return "visits" if text.match?(/variable_name = "visits"|type = "(?:list_|sublist_|k_opt|nearby_list_)/)

  "scalar"
end

# A fragment that starts inside a local-search phase is completed the way the
# pages describe a production config: a construction phase, then the
# local-search phase the fragment belongs to.
CONSTRUCTION = %([[phases]]\ntype = "construction_heuristic"\nconstruction_heuristic_type = "first_fit"\n\n)
# Assignment-owned slots are constructed through their group.
GROUPED_CONSTRUCTION = %([[phases]]\ntype = "construction_heuristic"\nconstruction_heuristic_type = "first_fit"\n) +
                       %(construction_obligation = "assign_when_candidate_exists"\ngroup_name = "required_shift_assignment"\n\n)

def wrap(text, model)
  return [text, nil] if text.match?(/^\[\[phases\]\]/)
  return [text, nil] unless text.match?(/^\[\[?phases\./)

  local_search =
    if text.match?(/^\[\[phases\.neighborhoods\]\]/)
      %([[phases]]\ntype = "local_search"\nlocal_search_type = "variable_neighborhood_descent"\n\n)
    else
      %([[phases]]\ntype = "local_search"\n\n)
    end
  construction = model == "grouped" ? GROUPED_CONSTRUCTION : CONSTRUCTION
  [construction + local_search + text, "construction + #{local_search.include?("variable") ? "VND" : "local_search"} phase"]
end

def toml_blocks
  PAGES.flat_map do |path|
    fences(read(path), "toml").map do |fence|
      marker = fence[:before][/<!--\s*sf-toml:(.*?)-->/, 1]
      expect = marker && marker[/expect="([^"]+)"/, 1]
      message = marker && marker[/message="([^"]+)"/, 1]
      if marker && !%w[parse-error solve-error].include?(expect)
        fail!("#{rel(path)}:#{fence[:line]}: sf-toml marker needs expect=\"parse-error\" or expect=\"solve-error\"")
      end
      fail!("#{rel(path)}:#{fence[:line]}: sf-toml marker needs message=\"...\"") if marker && message.to_s.empty?

      reason = PARSE_ONLY.find { |pattern, _| fence[:text].match?(pattern) }&.last
      model = reason ? "parse" : model_for(fence[:text])
      text, wrapped = wrap(fence[:text], model)
      Block.new(page: rel(path), line: fence[:line], text: text, expect: expect, message: message,
                model: model, reason: reason, wrapped: wrapped)
    end
  end
end

def dedent(text)
  lines = text.lines.map(&:rstrip)
  indent = lines.reject(&:empty?).map { |line| line[/\A */].size }.min || 0
  lines.map { |line| line[indent..] || "" }.join("\n").strip
end

# `// page: <path> <label>` ... `// end page` regions of the fixture sources.
def fixture_regions
  Dir.glob(File.join(FIXTURE, "src/**/*.rs")).sort.flat_map do |path|
    regions = []
    current = nil
    File.readlines(path).each_with_index do |line, index|
      if (match = line.match(%r{^\s*// page: (\S+)(?: (.*))?$}))
        current = { file: rel(path), line: index + 1, page: match[1], label: match[2].to_s.strip, body: [] }
      elsif line.match?(%r{^\s*// end page\s*$})
        fail!("#{rel(path)}:#{index + 1}: `// end page` without `// page:`") unless current
        regions << current.merge(text: dedent(current[:body].join))
        current = nil
      elsif current
        current[:body] << line
      end
    end
    fail!("#{rel(path)}: unterminated `// page:` region at line #{current[:line]}") if current
    regions
  end
end

def static_contract
  fail!("expected #{EXPECTED_PAGE_COUNT} solver pages, found #{PAGES.length}") unless PAGES.length == EXPECTED_PAGE_COUNT

  failures = []

  log "Checking every Rust block on the solver pages against the fixture"
  regions = fixture_regions
  used = []
  rust_count = 0
  PAGES.each do |path|
    fences(read(path), "rust").each do |fence|
      rust_count += 1
      match = regions.find { |region| region[:page] == rel(path) && region[:text] == dedent(fence[:text]) }
      if match
        used << match
      else
        failures << "#{rel(path)}:#{fence[:line]}: Rust block is not verbatim in any `// page: #{rel(path)}` fixture region"
      end
    end
  end
  (regions - used).each do |region|
    failures << "#{region[:file]}:#{region[:line]}: fixture region `#{region[:page]} #{region[:label]}` matches no Rust block on that page"
  end
  log "  #{rust_count} Rust blocks, #{regions.length} fixture regions"

  log "Checking the fixture solver.toml is the configuration page's example"
  config_page = read(File.join(SITE_ROOT, "src/docs/solverforge/solver/configuration.md"))
  example = read(File.join(FIXTURE, "solver.toml"))
  unless fences(config_page, "toml").any? { |fence| fence[:text] == example }
    failures << "scripts/fixtures/solver-config/solver.toml is not a ```toml block of configuration.md"
  end

  blocks = toml_blocks
  fail!("found no ```toml blocks on the solver pages") if blocks.empty?
  log "  #{blocks.length} TOML blocks on #{PAGES.length} pages"
  [blocks, failures]
end

def cargo!(*args, chdir:, env: {})
  output, status = Open3.capture2e(env.merge("CARGO_BUILD_JOBS" => ENV.fetch("CARGO_BUILD_JOBS", "3")), "cargo", *args, chdir: chdir)
  [output, status]
end

def build_fixture(target)
  _, status = Open3.capture2e("cargo", "--version")
  fail!("cargo is required for the live run") unless status.success?

  log "Building the fixture against crates.io solverforge =0.26.1"
  output, status = cargo!("build", "--locked", "--quiet", chdir: FIXTURE, env: { "CARGO_TARGET_DIR" => target })
  fail!("fixture build failed:\n#{output}") unless status.success?
  binary = File.join(target, "debug", "solver-config-fixture")
  fail!("fixture binary missing at #{binary}") unless File.executable?(binary)
  binary
end

def check_blocks(binary, blocks, failures)
  log "Parsing and solving #{blocks.length} TOML blocks"
  results = Array.new(blocks.length)
  Dir.mktmpdir("solver-config-blocks.") do |dir|
    queue = Queue.new
    blocks.each_with_index { |block, index| queue << [block, index] }
    workers = Array.new(4) do
      Thread.new do
        loop do
          block, index = begin
            queue.pop(true)
          rescue ThreadError
            break
          end
          file = File.join(dir, "block-#{index}.toml")
          File.write(file, block.text)
          output, status = Open3.capture2e(binary, "check", block.model, file)
          results[index] = [output, status]
        end
      end
    end
    workers.each(&:join)
  end

  parsed = solved = 0
  blocks.each_with_index do |block, index|
    output, status = results[index]
    fail!("#{block.where}: block was never checked") unless output
    parse_line = output[/^PARSE_(?:OK|ERR).*$/]
    solve_line = output[/^SOLVE_(?:OK|ERR).*$/]
    unless status.success? && parse_line
      failures << "#{block.where}: fixture crashed (exit #{status.exitstatus}): #{output.lines.last(3).join.strip}"
      next
    end

    case block.expect
    when "parse-error"
      if parse_line.start_with?("PARSE_ERR") && parse_line.include?(block.message)
        parsed += 1
      else
        failures << "#{block.where}: expected a parse error containing `#{block.message}`, got: #{parse_line}"
      end
      next
    end
    unless parse_line == "PARSE_OK"
      failures << "#{block.where}: #{parse_line.sub("PARSE_ERR ", "does not parse: ")}"
      next
    end
    parsed += 1
    next if block.model == "parse"

    if block.expect == "solve-error"
      if solve_line.to_s.start_with?("SOLVE_ERR") && solve_line.include?(block.message)
        solved += 1
      else
        failures << "#{block.where}: expected a solve error containing `#{block.message}`, got: #{solve_line.inspect}"
      end
    elsif solve_line.to_s.start_with?("SOLVE_OK")
      solved += 1
    else
      failures << "#{block.where} (#{block.model} model): #{solve_line ? solve_line.sub("SOLVE_ERR ", "solve fails: ") : "no solve result"}"
    end
  end

  parse_only = blocks.count { |block| block.model == "parse" }
  solvable = blocks.count { |block| block.model != "parse" && block.expect != "parse-error" }
  log "  parsed as stated #{parsed}/#{blocks.length}; solved as stated #{solved}/#{solvable}; parse-only #{parse_only}"
  blocks.select(&:reason).group_by(&:reason).each do |reason, group|
    log "    parse-only (#{reason}): #{group.map(&:where).join(", ")}"
  end
end

def run_scenarios(binary, failures)
  example = read(File.join(FIXTURE, "solver.toml"))
  SCENARIOS.each do |name, (description, expected_lines)|
    Dir.mktmpdir("solver-config-#{name}.") do |dir|
      case name
      when "config-load"
        File.write(File.join(dir, "solver.toml"), example)
      when "cwd-ignored"
        # Valid, and different from the embedded file: one construction phase.
        File.write(File.join(dir, "solver.toml"),
                   %([[phases]]\ntype = "construction_heuristic"\nconstruction_heuristic_type = "first_fit"\n))
      end
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      output, status = Open3.capture2e(binary, "scenario", name, chdir: dir)
      seconds = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
      missing = expected_lines.reject { |line| output.include?(line) }
      if status.success? && output.lines.last.to_s.strip == "SCENARIO #{name} OK" && missing.empty?
        log format("  scenario %-15s ok in %5.1fs  (%s)", name, seconds, description)
      else
        failures << "scenario #{name} (#{description}) failed (exit #{status.exitstatus}" \
                    "#{missing.empty? ? "" : ", missing output #{missing.inspect}"}):\n#{output.lines.last(15).join}"
      end
    end
  end
end

static_only = ARGV.include?("--static")
unknown = ARGV - ["--static"]
fail!("unknown arguments: #{unknown.join(" ")}") unless unknown.empty?

blocks, failures = static_contract
unless static_only
  target = ENV.fetch("SOLVER_CONFIG_TARGET_DIR", File.join(Dir.tmpdir, "solver-config-target"))
  binary = build_fixture(target)
  check_blocks(binary, blocks, failures)
  log "Running the lifecycle snippets"
  run_scenarios(binary, failures)
end

unless failures.empty?
  warn "[verify-solver-config] #{failures.length} failure(s):"
  failures.each { |failure| warn "  - #{failure}" }
  exit 1
end
log(static_only ? "Static contract holds" : "All solver blocks parse and solve; lifecycle snippets hold")
