#!/usr/bin/env ruby
# frozen_string_literal: true

# Holds /docs/concepts/serio/ to what SERIO actually does.
#
# The page traces one move through the score director. The trace crate is
# the page's own model and constraint files (the `crate=serio` blocks) plus
# the fixture's src/main.rs, which drives the score director and defines no
# model of its own. Its shift table must be the fixture's input, and its score
# column must be what that crate prints when built against the published
# solverforge release (RustPages::RELEASE, from crates.io), with every kept
# score equal to a fresh full evaluation. Nothing here skips: a missing tool
# or a failed build is a failure.
#
#   ruby scripts/verify-serio-page.rb            # static + live
#   ruby scripts/verify-serio-page.rb --static   # page/fixture contract only
#
# The live run needs cargo and the crates.io index. SERIO_TRACE_TARGET_DIR
# (or SOLVERFORGE_SNIPPETS_TARGET_DIR) keeps the build between runs.

require "fileutils"
require "open3"
require "tmpdir"

require_relative "lib/rust_pages"

SITE_ROOT = File.expand_path("..", __dir__)
PAGE_PATH = "src/docs/concepts/serio.md"
PAGE = File.join(SITE_ROOT, PAGE_PATH)
PAGE_URL = "/docs/concepts/serio/"
FIXTURE = File.join(SITE_ROOT, "scripts/fixtures/serio-trace/src/main.rs")
RELEASE = RustPages::RELEASE

# Page step label => fixture step name. "Retract" has no fresh check: the
# entity is mid-move, so the solution and the kept score describe different
# states by design.
STEPS = {
  "Initialize" => "initialize",
  "Retract shift 1" => "retract",
  "Insert shift 1" => "insert",
  "Undo" => "undo"
}.freeze

WIRING = {
  "src/_data/docs_nav.yml" => ["href: /docs/concepts/serio/"],
  "src/docs/concepts/index.md" => ["(/docs/concepts/serio/)"],
  "src/docs/architecture.md" => ["(/docs/concepts/serio/)"],
  "src/about.md" => ["'/docs/concepts/serio/'"]
}.freeze

def log(message)
  puts "[verify-serio-page] #{message}"
end

def fail!(message)
  warn "[verify-serio-page] ERROR: #{message}"
  exit 1
end

def read(path)
  fail!("missing file: #{path.delete_prefix("#{SITE_ROOT}/")}") unless File.file?(path)
  File.read(path)
end

# Markdown table rows after the header line that starts with `header`.
def table_rows(text, header)
  lines = text.lines.map(&:strip)
  start = lines.index { |line| line.start_with?("| #{header} |") }
  fail!("page has no table headed '#{header}'") unless start
  lines[(start + 2)..].take_while { |line| line.start_with?("|") }.map do |line|
    line.split("|")[1..].map(&:strip)
  end
end

def static_contract
  page = read(PAGE)
  fixture = read(FIXTURE)

  log "Checking the page's model and constraint files"
  plan = RustPages::Plan.new(SITE_ROOT, [PAGE_PATH], RELEASE).build!
  fail!(plan.errors.join("\n")) unless plan.errors.empty?
  crate = plan.crates["serio"] or fail!("page has no crate=serio blocks")
  stray = plan.rust_blocks.reject { |block| crate.files.values.map(&:block).include?(block) }
  fail!("every Rust block on the page must be a crate=serio file: #{stray.map(&:where).join(', ')}") unless stray.empty?
  wanted = %w[src/domain/mod.rs src/domain/model.rs src/constraints.rs]
  fail!("page must show #{wanted.join(', ')}; it shows #{crate.files.keys.sort.join(', ')}") unless crate.files.keys.sort == wanted.sort
  if fixture.match?(/#\[planning_solution|fn define_constraints|__internal|PlanningModelSupport/)
    fail!("the fixture must use the page's model and constraints, not define or implement its own")
  end

  log "Checking the shift table against the fixture input"
  shifts = table_rows(page, "Shift").map do |id, hours, employee|
    start, finish = hours.split("–")
    { id: id, start: start, end: finish, employee: employee }
  end
  literals = fixture.scan(/Shift \{ id: (\d+), start: (\d+), end: (\d+), employee_idx: (Some\((\d+)\)|None) \}/)
  expected = literals.map do |id, start, finish, _, employee|
    { id: id, start: start, end: finish, employee: employee || "none" }
  end
  fail!("shift table #{shifts.inspect} != fixture input #{expected.inspect}") unless shifts == expected

  log "Checking the trace table's steps"
  steps = table_rows(page, "Step").map { |label, _touches, score| [label, score.delete("`")] }
  fail!("trace steps #{steps.map(&:first).inspect} != #{STEPS.keys.inspect}") unless steps.map(&:first) == STEPS.keys

  log "Checking navigation and cross-links"
  WIRING.each do |relative, needles|
    text = read(File.join(SITE_ROOT, relative))
    needles.each { |needle| fail!("#{relative} is missing #{needle}") unless text.include?(needle) }
  end

  [steps.to_h, crate]
end

def live_trace(expected, crate)
  _, status = Open3.capture2e("cargo", "--version")
  fail!("cargo is required for the live trace") unless status.success?

  Dir.mktmpdir("serio-trace") do |dir|
    crate.files.each_value do |file|
      path = File.join(dir, file.path)
      FileUtils.mkdir_p(File.dirname(path))
      File.write(path, file.code)
    end
    FileUtils.cp(FIXTURE, File.join(dir, "src/main.rs"))
    File.write(File.join(dir, "Cargo.toml"), <<~TOML)
      [package]
      name = "serio-trace"
      version = "0.0.0"
      edition = "2024"

      [dependencies]
      solverforge = "=#{RELEASE}"
    TOML

    log "Building and running the trace against crates.io solverforge #{RELEASE}"
    target = ENV["SERIO_TRACE_TARGET_DIR"] || ENV["SOLVERFORGE_SNIPPETS_TARGET_DIR"] || File.join(dir, "target")
    output, status = Open3.capture2e({ "CARGO_TARGET_DIR" => target }, "cargo", "run", "--quiet", chdir: dir)
    fail!("trace did not run:\n#{output}") unless status.success?

    printed = output.lines.grep(/\Astep=/).to_h do |line|
      fields = line.split.to_h { |pair| pair.split("=", 2) }
      [fields.fetch("step"), fields]
    end

    STEPS.each do |label, step|
      fields = printed[step] or fail!("trace printed no #{step} step")
      fail!("#{label}: page says #{expected[label]}, the director reports #{fields['score']}") unless fields["score"] == expected[label]
      next if step == "retract"

      fail!("#{label}: kept score #{fields['score']} != fresh evaluation #{fields['fresh']}") unless fields["fresh"] == fields["score"]
    end
  end
  log "Trace matches the page: #{expected.values.join(' -> ')}"
end

expected, crate = static_contract
if ARGV.include?("--static")
  log "Static contract passed"
else
  live_trace(expected, crate)
  log "Contract passed"
end
