#!/usr/bin/env ruby
# frozen_string_literal: true

# Holds /docs/concepts/serio/ to what SERIO actually does.
#
# The page traces one move through the score director. Its constraint
# function must be verbatim in the published fixture, its shift table must be
# the fixture's input, and its score column must be what the fixture prints
# when built against the documented solverforge tag, with every kept score
# equal to a fresh full evaluation. Nothing here skips: a missing repository,
# tool, or build is a failure.
#
#   ruby scripts/verify-serio-page.rb            # static + live
#   ruby scripts/verify-serio-page.rb --static   # page/fixture contract only
#
# The live run needs cargo and the solverforge repository (SOLVERFORGE_RS_REPO,
# default /srv/lab/dev/solverforge/solverforge) holding SOLVERFORGE_RS_REF.

require "fileutils"
require "open3"
require "tmpdir"

SITE_ROOT = File.expand_path("..", __dir__)
PAGE = File.join(SITE_ROOT, "src/docs/concepts/serio.md")
PAGE_URL = "/docs/concepts/serio/"
FIXTURE = File.join(SITE_ROOT, "scripts/fixtures/serio-trace/src/main.rs")
RS_REPO = ENV.fetch("SOLVERFORGE_RS_REPO", "/srv/lab/dev/solverforge/solverforge")
RS_REF = ENV.fetch("SOLVERFORGE_RS_REF", "v0.23.0")

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

  log "Checking the constraint function against the fixture"
  rust = page.scan(/^```rust\n(.*?)^```/m).map(&:first)
  fail!("page must carry exactly one Rust block, found #{rust.length}") unless rust.length == 1
  fail!("the page's constraint function is not verbatim in the fixture") unless fixture.include?(rust.first)

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

  steps.to_h
end

def live_trace(expected)
  fail!("SOLVERFORGE_RS_REPO #{RS_REPO} is not a git repository") unless File.directory?(File.join(RS_REPO, ".git")) || File.file?(File.join(RS_REPO, ".git"))
  _, status = Open3.capture2e("git", "-C", RS_REPO, "rev-parse", "--verify", "#{RS_REF}^{commit}")
  fail!("#{RS_REPO} has no #{RS_REF}") unless status.success?
  _, status = Open3.capture2e("cargo", "--version")
  fail!("cargo is required for the live trace") unless status.success?

  Dir.mktmpdir("serio-trace") do |dir|
    FileUtils.mkdir_p(File.join(dir, "src"))
    FileUtils.cp(FIXTURE, File.join(dir, "src/main.rs"))
    File.write(File.join(dir, "Cargo.toml"), <<~TOML)
      [package]
      name = "serio-trace"
      version = "0.0.0"
      edition = "2021"

      [dependencies]
      solverforge = { git = "file://#{RS_REPO}", tag = "#{RS_REF}", package = "solverforge" }
    TOML

    log "Building and running the trace against solverforge #{RS_REF}"
    target = ENV.fetch("SERIO_TRACE_TARGET_DIR", File.join(dir, "target"))
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

expected = static_contract
if ARGV.include?("--static")
  log "Static contract passed"
else
  live_trace(expected)
  log "Contract passed"
end
