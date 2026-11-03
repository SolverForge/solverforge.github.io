#!/usr/bin/env ruby
# frozen_string_literal: true

# Compiles every Rust block on the Rust library pages exactly as a reader
# would assemble it, against the published solverforge crate, and runs every
# program whose output a page shows.
#
#   ruby scripts/verify-rust-snippets.rb            # assemble, cargo check, cargo run, compare
#   ruby scripts/verify-rust-snippets.rb --static   # markers, slots, excerpts and links only
#   ruby scripts/verify-rust-snippets.rb --list     # print every block and where it compiles
#
# Pages are listed in scripts/lib/rust_snippet_scope.rb. The crate version is
# RustPages::RELEASE (scripts/lib/rust_pages.rb), which verify-release-surface.rb
# holds to the current release and which src/docs/solverforge/index.md must
# tell the reader to install (`cargo add solverforge@=X.Y.Z`). How a page
# marks a block is documented in scripts/lib/rust_pages.rb. Nothing is
# skipped: every Rust block is either compiled in a crate or quoted verbatim
# from a compiled file. Every finding is collected; the gate exits non-zero
# after reporting all of them.
#
# Cargo needs the crates.io index. SOLVERFORGE_SNIPPETS_TARGET_DIR keeps the
# build cache between runs (default: a directory under the system temp dir).

require "fileutils"
require "json"
require "open3"
require "optparse"
require "tmpdir"

require_relative "lib/rust_pages"
require_relative "lib/rust_snippet_scope"

ROOT = RustPages::ROOT
$stdout.sync = true

def log(message)
  puts "[verify-rust-snippets] #{message}"
end

def fail!(message)
  warn "[verify-rust-snippets] ERROR: #{message}"
  exit 1
end

POLICY = {
  /solverforge::__internal|PlanningModelSupport/ => "pages must not use solverforge::__internal; a reader cannot implement it",
  /stream::vec\b|\bvec\(\s*\|/ => "solverforge::stream::vec is not part of the published crate",
  /factory\.clone\(\)/ => "construct a fresh ConstraintFactory instead of cloning one"
}.freeze

def policy_errors(plan)
  plan.rust_blocks.flat_map do |block|
    POLICY.filter_map { |pattern, message| "#{block.where}: #{message}" if block.code.match?(pattern) }
  end
end

def list(plan)
  plan.crates.each_value.sort_by(&:name).each do |crate|
    puts "crate #{crate.name} (home #{crate.home}#{", extends #{crate.extends}" if crate.extends})"
    crate.files.each_value { |file| puts "  file    #{file.path.ljust(28)} #{file.block.where}#{" slot=#{file.slot}" if file.slot}" }
    crate.fragments.each { |block| puts "  in      #{block.marker['in'].ljust(28)} #{block.where}" }
    crate.excerpts.each { |block| puts "  excerpt #{''.ljust(28)} #{block.where}" }
    crate.outputs.each { |block| puts "  output  #{''.ljust(28)} #{block.where}" }
  end
end

def cargo(env, args, chdir:)
  Open3.capture3(env, "cargo", *args, chdir: chdir)
end

def primary_location(span)
  while span
    return span unless span["file_name"].to_s.start_with?("/")

    span = span.dig("expansion", "span")
  end
  nil
end

# Runs cargo check over the workspace and returns failures keyed by page block.
def check(workspace, env, crates)
  stdout, stderr, status = cargo(
    env, ["check", "--workspace", "--keep-going", "--message-format=json"], chdir: workspace.dir
  )
  failures = Hash.new { |hash, key| hash[key] = [] }
  failed_packages = []
  stdout.each_line do |line|
    message = JSON.parse(line) rescue next
    next unless message["reason"] == "compiler-message"

    diagnostic = message["message"]
    next unless diagnostic["level"] == "error"

    package = message["package_id"].to_s[%r{/(sf-[a-z0-9-]+)#}, 1] || message["package_id"].to_s[/(sf-[a-z0-9-]+)/, 1]
    failed_packages << package
    span = diagnostic["spans"].find { |candidate| candidate["is_primary"] } || diagnostic["spans"].first
    span = primary_location(span) if span
    located = span && [workspace.dir, File.join(workspace.dir, package.to_s)].lazy.map do |base|
      workspace.locate(File.join(base, span["file_name"]), span["line_start"])
    end.find(&:itself)
    key = located ? located.first : package
    failures[key] << { line: located&.last, text: diagnostic["rendered"].to_s, package: package }
  end
  unless status.success? || failures.any?
    fail!("cargo check failed without a compiler diagnostic:\n#{stderr}")
  end
  [failures, failed_packages.compact.uniq]
end

def run_outputs(workspace, env, plan, failed_packages)
  failures = []
  plan.crates.each_value.select { |crate| crate.outputs.any? }.each do |crate|
    if failed_packages.include?(crate.package)
      failures << "#{crate.outputs.first.where}: crate #{crate.name} does not compile, so its output was not produced"
      next
    end
    stdout, stderr, status = cargo(env, ["run", "--quiet", "-p", crate.package], chdir: workspace.dir)
    unless status.success?
      failures << "#{crate.outputs.first.where}: `cargo run` of crate #{crate.name} failed:\n#{stderr}"
      next
    end
    actual = stdout.lines.map(&:rstrip).join("\n").strip
    crate.outputs.each do |block|
      expected = block.code.lines.map(&:rstrip).join("\n").strip
      if expected == actual
        log "output #{block.where} matches `cargo run` of #{crate.name}"
      else
        failures << "#{block.where}: page shows\n#{expected}\n--- but `cargo run` of crate #{crate.name} prints\n#{actual}"
      end
    end
  end
  failures
end

options = { static: false, list: false, keep: false, only: nil }
OptionParser.new do |parser|
  parser.banner = "Usage: ruby scripts/verify-rust-snippets.rb [--static|--list] [--keep]"
  parser.on("--static", "Check markers, slots, excerpts and links without cargo") { options[:static] = true }
  parser.on("--list", "List every crate and the blocks it is assembled from") { options[:list] = true }
  parser.on("--keep", "Keep the generated Cargo workspace") { options[:keep] = true }
  parser.on("--only PAGE", "Compile only the crates PAGE uses (a debugging aid; the gate is the full run)") { |page| options[:only] = page }
end.parse!

begin
  version = RustPages::RELEASE
  pages = RustSnippetScope.pages(ROOT).map { |path| path.delete_prefix("#{ROOT}/") }
  plan = RustPages::Plan.new(ROOT, pages, version).build!
rescue RustPages::Error => e
  fail!(e.message)
end
plan.errors.concat(RustPages.install_line_errors, policy_errors(plan))

if options[:list]
  list(plan)
  exit 0
end

rust = plan.rust_blocks
log "#{pages.size} pages, #{rust.size} Rust blocks, #{plan.crates.size} crates against solverforge #{version}"
plan.errors.each { |error| warn "[verify-rust-snippets] ERROR: #{error}" }
if options[:static]
  fail!("#{plan.errors.size} page contract errors") unless plan.errors.empty?
  log "Static contract passed"
  exit 0
end

fail!("cargo is required") unless system("cargo", "--version", out: File::NULL, err: File::NULL)

workdir = Dir.mktmpdir("rust-snippets")
target = ENV.fetch("SOLVERFORGE_SNIPPETS_TARGET_DIR", File.join(Dir.tmpdir, "solverforge-site-snippets-target"))
env = { "CARGO_TARGET_DIR" => target }
begin
  selected = plan.crates.values
  if options[:only]
    selected = selected.select { |crate| crate.uses.any? { |block| block.page == options[:only] } || crate.home == options[:only] }
    selected += selected.filter_map { |crate| plan.crates[crate.extends] if crate.extends }
    selected = selected.uniq
    rust = rust.select { |block| selected.any? { |crate| crate.blocks.include?(block) } }
    plan.crates.select! { |_, crate| selected.include?(crate) }
  end
  workspace = RustPages::Workspace.new(workdir, plan, selected.sort_by(&:name)).write!
  log "Checking #{plan.crates.size} crates in #{workdir} (target #{target})"
  failures, failed_packages = check(workspace, env, plan.crates.values)

  failed_blocks = []
  rust.each do |block|
    crate = plan.crates.values.find { |candidate| candidate.blocks.include?(block) }
    errors = failures[block]
    if errors.any?
      failed_blocks << block
      warn "FAIL #{block.where} (crate #{crate.name})"
      errors.each { |error| warn "  page line #{error[:line]}:\n#{error[:text].gsub(/^/, '    ')}" }
    elsif failed_packages.include?(crate.package)
      failed_blocks << block
      warn "FAIL #{block.where} (no error in this block; crate #{crate.name} does not compile)"
    end
  end
  failures.each do |key, errors|
    next if key.is_a?(RustPages::Block)

    errors.each { |error| warn "FAIL crate #{key}:\n#{error[:text].gsub(/^/, '    ')}" }
  end

  output_failures = run_outputs(workspace, env, plan, failed_packages)
  output_failures.each { |failure| warn "FAIL #{failure}" }

  unless failed_blocks.empty? && failed_packages.empty? && plan.errors.empty? && output_failures.empty?
    fail!("#{failed_blocks.size} of #{rust.size} Rust blocks do not compile; " \
          "#{output_failures.size} shown outputs differ; #{plan.errors.size} page contract errors")
  end
  log "All #{rust.size} Rust blocks compile against solverforge #{version}, and every shown output matches"

  log "Contract passed"
ensure
  if options[:keep]
    log "Kept workspace #{workdir}"
  else
    FileUtils.rm_rf(workdir)
  end
end
