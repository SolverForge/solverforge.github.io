#!/usr/bin/env ruby
# frozen_string_literal: true

require "fileutils"
require "open3"
require "tmpdir"

EXPECTED_CLI_VERSION = "2.0.0"
EXPECTED_RUNTIME_VERSION = "0.9.0"
EXPECTED_UI_VERSION = "0.6.1"
EXPECTED_MAPS_VERSION = "2.1.3"

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
  assert_contains(version_output, "Runtime source: crates.io: solverforge #{EXPECTED_RUNTIME_VERSION}", "solverforge --version")
  assert_contains(version_output, "UI source: crates.io: solverforge-ui #{EXPECTED_UI_VERSION}", "solverforge --version")
  assert_contains(version_output, "Maps source: crates.io: solverforge-maps #{EXPECTED_MAPS_VERSION}", "solverforge --version")

  run_command(cli, "new", "release-gate", "--skip-git", "--skip-readme", "--quiet", chdir: scaffold_root)

  app_root = File.join(scaffold_root, "release-gate")
  assert_file_contains(File.join(app_root, "Cargo.toml"), "solverforge = { version = \"#{EXPECTED_RUNTIME_VERSION}\", features = [\"serde\", \"console\", \"verbose-logging\"] }")
  assert_file_contains(File.join(app_root, "Cargo.toml"), "solverforge-ui = { version = \"#{EXPECTED_UI_VERSION}\" }")
  assert_file_contains(File.join(app_root, "Cargo.toml"), "solverforge-maps = { version = \"#{EXPECTED_MAPS_VERSION}\" }")
  assert_file_contains(File.join(app_root, "solverforge.app.toml"), "cli_version = \"#{EXPECTED_CLI_VERSION}\"")
  assert_file_contains(File.join(app_root, "solverforge.app.toml"), "target = \"solverforge #{EXPECTED_RUNTIME_VERSION}\"")
  assert_file_contains(File.join(app_root, "solverforge.app.toml"), "ui_source = \"crates.io: solverforge-ui #{EXPECTED_UI_VERSION}\"")

  log "Published CLI release matches the documented scaffold targets"
end
