#!/usr/bin/env ruby
# frozen_string_literal: true

require "fileutils"
require "open3"
require "tmpdir"
require "digest"
require "json"
require "rubygems/version"

EXPECTED_SOURCE_SHA = "fcaad8e3ef59444cb28f7e4742494e2b0cbb64ca"
EXPECTED_ARTIFACT_SHA256 = "ba476ea2862d6e0a6e2f0a9a434428d2887f8863abdd1e932b6ef87598d7d538"

EXPECTED_CLI_VERSION = "3.7.1"
EXPECTED_RUNTIME_VERSION = "0.23.0"
EXPECTED_UI_VERSION = "0.9.0"
EXPECTED_MAPS_VERSION = "2.1.4"
EXPECTED_MCP_VERSION = "3.8.0"

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
  target_source = run_command("tar", "-xOf", artifact, "solverforge-cli-#{EXPECTED_CLI_VERSION}/src/scaffold_target.rs")
  { "RUNTIME" => EXPECTED_RUNTIME_VERSION, "UI" => EXPECTED_UI_VERSION,
    "MAPS" => EXPECTED_MAPS_VERSION, "MCP" => EXPECTED_MCP_VERSION }.each do |name, version|
    assert_contains(target_source, "pub const #{name}_CRATE_VERSION: &str = \"#{version}\";", "published scaffold target")
  end
  %w[scalar list].each do |family|
    template = run_command("tar", "-xOf", artifact, "solverforge-cli-#{EXPECTED_CLI_VERSION}/templates/#{family}/generic/solver.toml")
    ['# [move_thread_count]', '# count = 4', 'RAYON_NUM_THREADS', 'by 32'].each do |needle|
      assert_contains(template, needle, "#{family} parallel configuration template")
    end
  end
  log "Artifact checksum, source SHA, scaffold constants, and both parallel configuration templates verified: #{EXPECTED_SOURCE_SHA}"

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

  log version_output.strip

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
  mcp_server = File.join(mcp_root, "src", "mcp", "server.rs")
  assert_file_contains(mcp_server, "fn get_info(&self) -> ServerConfig")
  assert_file_contains(mcp_server, "ServerConfig::new(")
  fail!("MCP scaffold uses deprecated ServerInfo") if File.read(mcp_server).include?("ServerInfo")
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
  assert_file_contains(config, '# [move_thread_count]')
  assert_file_contains(config, '# count = 4')
  assert_file_contains(config, 'RAYON_NUM_THREADS')
  telemetry = File.join(app_root, "src", "api", "telemetry.rs")
  assert_file_contains(telemetry, 'pub phases: Vec<PhaseTelemetryDto>')
  assert_file_contains(telemetry, 'pub moves_speculative: u64')
  assert_file_contains(telemetry, '"discarded_speculative"')
  fail!("telemetry still exposes the old single-phase field") if File.read(telemetry).include?('pub phase: Option<PhaseTelemetryDto>')

  original_config = File.read(config)
  ['"auto"', '"none"', '{ count = 0 }', '{ count = 4 }'].each do |value|
    File.write(config, "move_thread_count = #{value}\n\n#{original_config}")
    run_command(cli, "check", "--quiet", chdir: app_root)
  end
  ['4', '"many"', '{ count = -1 }', '{ count = "four" }', '{}', '{ count = 4, threads = 4 }'].each do |value|
    File.write(config, "move_thread_count = #{value}\n\n#{original_config}")
    stdout, stderr, status = Open3.capture3(cli, "check", "--quiet", chdir: app_root)
    fail!("check accepted invalid move_thread_count #{value}") if status.success?
    assert_contains(stdout + stderr, "move_thread_count", "invalid thread-count diagnostic")
  end
  File.write(config, original_config)
  run_command(cli, "config", "set", "move_thread_count.count", "4", chdir: app_root)
  assert_contains(run_command(cli, "config", "show", chdir: app_root), "count = 4", "parallel config round trip")
  before_invalid_set = File.read(config)
  stdout, stderr, status = Open3.capture3(cli, "config", "set", "move_thread_count.count", "many", chdir: app_root)
  fail!("config set accepted a non-integer evaluator count") if status.success?
  assert_contains(stdout + stderr, "move_thread_count", "invalid config set diagnostic")
  fail!("invalid config set changed solver.toml") unless File.read(config) == before_invalid_set
  log "Thread-count validation: 4 valid forms, 6 invalid forms, dotted-key round trip and rejected-write preservation passed"

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

  [app_root, mcp_root, File.join(scaffold_root, "release-gate-api"), File.join(scaffold_root, "release-gate-cli")].each do |root|
    log "Compile-checking #{File.basename(root)} against published crates"
    run_command(cli, "check", "--quiet", chdir: root)
    run_command("cargo", "check", "--quiet", chdir: root)
  end

  log "Published CLI release matches the documented scaffold targets and generator/config behavior"
end
