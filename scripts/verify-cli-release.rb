#!/usr/bin/env ruby
# frozen_string_literal: true

require "fileutils"
require "open3"
require "tmpdir"
require "digest"
require "json"
require "rubygems/version"

EXPECTED_SOURCE_SHA = "bb53b77af84e6c7845a6749d41ad7aca9e653cd2"
EXPECTED_ARTIFACT_SHA256 = "64356b66f1b99eb5408253e425c0ce2c3bd6ac3899028ad79df4ed57fad922a9"

EXPECTED_CLI_VERSION = "3.5.2"
EXPECTED_RUNTIME_VERSION = "0.21.3"
EXPECTED_UI_VERSION = "0.9.0"
EXPECTED_MAPS_VERSION = "2.1.4"
EXPECTED_MCP_VERSION = "3.5.1"

def fail!(message)
  warn "[verify-cli-release] ERROR: #{message}"
  exit 1
end

def log(message)
  puts "[verify-cli-release] #{message}"
end

def run_command(*argv, chdir: nil)
  options = {}
  options[:chdir] = chdir if chdir
  stdout, stderr, status = Open3.capture3(*argv, **options)
  fail!("command failed: #{argv.join(" ")}\n#{stderr}") unless status.success?

  stdout
end

def assert_contains(text, needle, label)
  fail!("#{label} is missing: #{needle}") unless text.include?(needle)
end

def assert_file_contains(path, needle)
  fail!("missing file: #{path}") unless File.file?(path)

  assert_contains(File.read(path), needle, path)
end

Dir.mktmpdir("solverforge-cli-release.") do |tmp_dir|
  install_root = File.join(tmp_dir, "install")
  scaffold_root = File.join(tmp_dir, "scaffold")
  FileUtils.mkdir_p(scaffold_root)

  index = run_command("curl", "--fail", "--silent", "--show-error", "--location", "https://index.crates.io/so/lv/solverforge-cli")
  rows = index.lines.map { |line| JSON.parse(line) }
  latest = rows.reject { |row| row.fetch("yanked") || row.fetch("vers").include?("-") }
               .max_by { |row| Gem::Version.new(row.fetch("vers")) }
  fail!("current published CLI is #{latest.fetch('vers')}; update the CLI manual and release gate") unless latest.fetch("vers") == EXPECTED_CLI_VERSION
  fail!("registry checksum differs from audited artifact") unless latest.fetch("cksum") == EXPECTED_ARTIFACT_SHA256
  artifact = File.join(tmp_dir, "solverforge-cli.crate")
  run_command("curl", "--fail", "--silent", "--show-error", "--location",
              "https://static.crates.io/crates/solverforge-cli/solverforge-cli-#{EXPECTED_CLI_VERSION}.crate", "--output", artifact)
  fail!("published artifact checksum mismatch") unless Digest::SHA256.file(artifact).hexdigest == latest.fetch("cksum")
  vcs = JSON.parse(run_command("tar", "-xOf", artifact, "solverforge-cli-#{EXPECTED_CLI_VERSION}/.cargo_vcs_info.json"))
  fail!("published artifact source SHA mismatch") unless vcs.fetch("git").fetch("sha1") == EXPECTED_SOURCE_SHA
  log "Artifact checksum and source SHA verified: #{EXPECTED_SOURCE_SHA}"

  log "Installing solverforge-cli #{EXPECTED_CLI_VERSION} from crates.io"
  run_command(
    "cargo",
    "install",
    "solverforge-cli",
    "--version",
    EXPECTED_CLI_VERSION,
    "--root",
    install_root,
    "--locked"
  )

  cli = File.join(install_root, "bin", "solverforge")
  fail!("missing installed CLI binary: #{cli}") unless File.executable?(cli)

  version_output = run_command(cli, "--version")
  assert_contains(version_output, "CLI version: #{EXPECTED_CLI_VERSION}", "solverforge --version")
  assert_contains(version_output, "Scaffold runtime target: SolverForge crate target #{EXPECTED_RUNTIME_VERSION}", "solverforge --version")
  assert_contains(version_output, "Scaffold UI target: solverforge-ui #{EXPECTED_UI_VERSION}", "solverforge --version")
  assert_contains(version_output, "Scaffold maps target: solverforge-maps #{EXPECTED_MAPS_VERSION}", "solverforge --version")
  assert_contains(version_output, "Scaffold MCP target: rmcp #{EXPECTED_MCP_VERSION}", "solverforge --version")
  assert_contains(version_output, "Runtime source: crates.io: solverforge #{EXPECTED_RUNTIME_VERSION}", "solverforge --version")
  assert_contains(version_output, "UI source: crates.io: solverforge-ui #{EXPECTED_UI_VERSION}", "solverforge --version")
  assert_contains(version_output, "Maps source: crates.io: solverforge-maps #{EXPECTED_MAPS_VERSION}", "solverforge --version")
  assert_contains(version_output, "MCP source: crates.io: rmcp #{EXPECTED_MCP_VERSION}", "solverforge --version")

  run_command(cli, "new", "release-gate", "--skip-git", "--skip-readme", "--quiet", chdir: scaffold_root)

  app_root = File.join(scaffold_root, "release-gate")
  assert_file_contains(File.join(app_root, "Cargo.toml"), "rust-version = \"1.95\"")
  assert_file_contains(File.join(app_root, "Cargo.toml"), "solverforge = { version = \"#{EXPECTED_RUNTIME_VERSION}\", features = [\"serde\", \"console\", \"verbose-logging\"] }")
  assert_file_contains(File.join(app_root, "Cargo.toml"), "solverforge-ui = { version = \"#{EXPECTED_UI_VERSION}\" }")
  assert_file_contains(File.join(app_root, "Cargo.toml"), "solverforge-maps = { version = \"#{EXPECTED_MAPS_VERSION}\" }")
  assert_file_contains(File.join(app_root, "solverforge.app.toml"), "cli_version = \"#{EXPECTED_CLI_VERSION}\"")
  assert_file_contains(File.join(app_root, "solverforge.app.toml"), "target = \"solverforge #{EXPECTED_RUNTIME_VERSION}\"")
  assert_file_contains(File.join(app_root, "solverforge.app.toml"), "ui_source = \"crates.io: solverforge-ui #{EXPECTED_UI_VERSION}\"")

  mcp_root = File.join(scaffold_root, "release-gate-mcp")
  run_command(cli, "new", "release-gate-mcp", "--shell", "mcp", "--skip-git", "--skip-readme", "--quiet", chdir: scaffold_root)
  assert_file_contains(File.join(mcp_root, "Cargo.toml"), "rmcp = { version = \"#{EXPECTED_MCP_VERSION}\"")
  assert_file_contains(File.join(mcp_root, "solverforge.app.toml"), "shell = \"mcp\"")
  assert_file_contains(File.join(mcp_root, "solverforge.app.toml"), "target = \"solverforge #{EXPECTED_RUNTIME_VERSION}\"")
  fail!("MCP scaffold should not pin solverforge-ui") if File.read(File.join(mcp_root, "Cargo.toml")).include?("solverforge-ui")

  %w[api cli].each do |shell|
    name = "release-gate-#{shell}"
    run_command(cli, "new", name, "--shell", shell, "--skip-git", "--skip-readme", "--quiet", chdir: scaffold_root)
    root = File.join(scaffold_root, name)
    manifest = File.read(File.join(root, "Cargo.toml"))
    assert_contains(manifest, "version = \"#{EXPECTED_RUNTIME_VERSION}\"", "#{shell} runtime")
    assert_file_contains(File.join(root, "solverforge.app.toml"), "shell = \"#{shell}\"")
    fail!("#{shell} scaffold should not include frontend dependencies") if manifest.match?(/solverforge-(?:ui|maps)/)
    fail!("#{shell} scaffold should not contain static assets") if File.exist?(File.join(root, "static"))
  end

  config = File.join(app_root, "solver.toml")
  ['construction_heuristic_type = "first_fit"', 'type = "late_acceptance"',
   'late_acceptance_size = 400', 'type = "accepted_count"', 'limit = 4',
   'seconds_spent_limit = 30'].each { |needle| assert_file_contains(config, needle) }
  run_command(cli, "config", "set", "termination.seconds_spent_limit", "60", chdir: app_root)
  assert_contains(run_command(cli, "config", "show", chdir: app_root), "seconds_spent_limit = 60", "config round trip")
  run_command(cli, "generate", "fact", "resource", "--quiet", chdir: app_root)
  run_command(cli, "generate", "entity", "task", "--quiet", chdir: app_root)
  run_command(cli, "generate", "variable", "resource_idx", "--entity", "Task", "--kind", "scalar", "--range", "resources", "--allows-unassigned", "--quiet", chdir: app_root)
  run_command(cli, "generate", "constraint", "assigned", "--unary", "--hard", "--quiet", chdir: app_root)
  run_command(cli, "generate", "score", "HardSoftDecimalScore", "--quiet", chdir: app_root)
  assert_file_contains(File.join(app_root, "src", "constraints", "assigned.rs"), "HardSoftDecimalScore")
  assert_file_contains(File.join(app_root, "solverforge.app.toml"), 'score = "HardSoftDecimalScore"')
  run_command(cli, "check", "--quiet", chdir: app_root)
  run_command(cli, "destroy", "--yes", "constraint", "assigned", "--quiet", chdir: app_root)
  fail!("destroy left the constraint behind") if File.exist?(File.join(app_root, "src", "constraints", "assigned.rs"))

  log "Published CLI release matches the documented scaffold targets and generator/config behavior"
end
