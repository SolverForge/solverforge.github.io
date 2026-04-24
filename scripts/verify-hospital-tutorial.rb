#!/usr/bin/env ruby
# frozen_string_literal: true

require "fileutils"
require "json"
require "net/http"
require "open3"
require "socket"
require "tmpdir"
require "timeout"
require "uri"

SCRIPT_DIR = File.expand_path(__dir__)
SITE_ROOT = File.expand_path("..", SCRIPT_DIR)
EXPECTED_CLI_VERSION = "2.0.0"
EXPECTED_RUNTIME_VERSION = "0.9.0"
EXPECTED_UI_VERSION = "0.6.1"
EXPECTED_MAPS_VERSION = "2.1.3"
EXPECTED_HOSPITAL_APP_CLI_VERSION = "0.9.0"

def log(message)
  puts "[verify-hospital-tutorial] #{message}"
end

def fail!(message)
  warn "[verify-hospital-tutorial] ERROR: #{message}"
  exit 1
end

def command?(name)
  ENV.fetch("PATH", "").split(File::PATH_SEPARATOR).any? do |dir|
    path = File.join(dir, name)
    File.file?(path) && File.executable?(path)
  end
end

def require_command(name)
  fail!("missing required command: #{name}") unless command?(name)
end

def discover_repo(env_name, candidates)
  configured = ENV[env_name]

  if configured && !configured.empty?
    path = File.expand_path(configured)
    fail!("#{env_name} points to missing repo: #{configured}") unless Dir.exist?(path)

    return path
  end

  candidates.each do |candidate|
    path = File.expand_path(candidate)
    return path if Dir.exist?(path)
  end

  nil
end

def read_file(path)
  fail!("missing file: #{path}") unless File.file?(path)

  File.read(path)
end

def assert_file_contains(path, needle)
  text = read_file(path)
  fail!("#{path} is missing: #{needle}") unless text.include?(needle)
end

def assert_file_not_contains(path, needle)
  text = read_file(path)
  fail!("#{path} still contains forbidden text: #{needle}") if text.include?(needle)
end

def assert_text_contains(text, needle, label)
  fail!("#{label} is missing: #{needle}") unless text.include?(needle)
end

def parse_json_file(path)
  JSON.parse(read_file(path))
rescue JSON::ParserError => e
  fail!("invalid JSON in #{path}: #{e.message}")
end

def assert_json_file(path)
  yield parse_json_file(path)
end

def run_command(*argv, chdir: nil, env: {})
  options = {}
  options[:chdir] = chdir if chdir
  stdout, stderr, status = Open3.capture3(env, *argv, **options)
  fail!("command failed: #{argv.join(" ")}\n#{stderr}") unless status.success?

  stdout
end

def run_system(*argv, chdir: nil, env: {})
  options = {}
  options[:chdir] = chdir if chdir
  system(env, *argv, **options) || fail!("command failed: #{argv.join(" ")}")
end

def free_port
  server = TCPServer.new("127.0.0.1", 0)
  server.addr[1]
ensure
  server&.close
end

def http_request(method, url, body: nil, headers: {})
  uri = URI(url)
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = uri.scheme == "https"
  http.open_timeout = 5
  http.read_timeout = 30

  request_class = Net::HTTP.const_get(method.to_s.capitalize)
  request = request_class.new(uri)
  headers.each { |key, value| request[key] = value }
  request.body = body if body

  http.request(request)
end

def http_get_body(url)
  response = http_request(:get, url)
  fail!("GET #{url} returned #{response.code}") unless response.is_a?(Net::HTTPSuccess)

  response.body
end

def wait_for_http_ok(url, max_attempts: 60)
  max_attempts.times do
    response = http_request(:get, url)
    return if response.is_a?(Net::HTTPSuccess)
  rescue StandardError
    nil
  ensure
    sleep 1 unless defined?(response) && response&.is_a?(Net::HTTPSuccess)
  end

  fail!("timed out waiting for #{url}")
end

def wait_for_json_endpoint(url, output_file, max_attempts: 60)
  last_status = nil

  max_attempts.times do
    response = http_request(:get, url)
    last_status = response.code
    if response.is_a?(Net::HTTPSuccess)
      File.write(output_file, response.body)
      return
    end
    sleep 1
  rescue StandardError => e
    last_status = e.class.name
    sleep 1
  end

  fail!("timed out waiting for #{url}; last status #{last_status}")
end

def first_sse_data_payload(url, timeout_seconds: 10)
  uri = URI(url)
  raw = +""

  Timeout.timeout(timeout_seconds) do
    Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https", read_timeout: timeout_seconds) do |http|
      request = Net::HTTP::Get.new(uri)
      catch(:done) do
        http.request(request) do |response|
          fail!("GET #{url} returned #{response.code}") unless response.is_a?(Net::HTTPSuccess)

          response.read_body do |chunk|
            raw << chunk
            throw :done if raw.match?(/^data: /)
          end
        end
      end
    end
  end

  raw
rescue Timeout::Error
  raw.match?(/^data: /) ? raw : nil
end

def json_field(json, field)
  field.split(".").reduce(json) do |value, part|
    value.is_a?(Array) ? value.fetch(Integer(part)) : value.fetch(part)
  end
end

def assert_rendered_h1_count
  rendered_doc = File.join(SITE_ROOT, "output/docs/getting-started/solverforge-hospital-use-case/index.html")

  unless File.file?(rendered_doc)
    log "Skipping rendered H1 check; build output not found at #{rendered_doc}"
    return
  end

  count = File.read(rendered_doc).scan(/<h1(?:\s|>)/i).size
  fail!("rendered hospital tutorial should have exactly one H1, found #{count}") unless count == 1
end

tmp_dir = Dir.mktmpdir("solverforge-hospital-tutorial.")
server_pid = nil

begin
  cli_repo = discover_repo("SOLVERFORGE_CLI_REPO", [
    File.join(SITE_ROOT, "../solverforge-cli"),
    File.join(SITE_ROOT, "../../solverforge-cli")
  ])

  if cli_repo
    log "Using CLI repo: #{cli_repo}"
  else
    log "Skipping CLI scaffold checks; set SOLVERFORGE_CLI_REPO to enable them."
  end

  hospital_repo = discover_repo("SOLVERFORGE_HOSPITAL_REPO", [
    File.join(SITE_ROOT, "../solverforge-hospital"),
    File.join(SITE_ROOT, "../../solverforge-hospital")
  ])

  if hospital_repo
    log "Using hospital repo: #{hospital_repo}"
  else
    log "Skipping live hospital app checks; set SOLVERFORGE_HOSPITAL_REPO to enable them."
  end

  doc_page = File.join(SITE_ROOT, "src/docs/getting-started/solverforge-hospital-use-case.md")
  hub_page = File.join(SITE_ROOT, "src/docs/getting-started/index.md")
  home_page = File.join(SITE_ROOT, "src/index.md")
  search_surface = File.join(SITE_ROOT, "src/_components/shared/search_surface.rb")

  log "Checking public copy and tutorial snippets"
  assert_file_contains(home_page, "Start with solverforge-cli")
  assert_file_contains(home_page, "Continue with the Hospital Use Case")
  assert_file_contains(hub_page, "Start with **`solverforge-cli`** for the generic project shell.")
  assert_file_contains(hub_page, "one concrete worked")
  assert_file_contains(search_surface, "Continue from the CLI guide into one concrete hospital use case.")

  assert_file_contains(doc_page, "cargo install solverforge-cli")
  assert_file_contains(doc_page, "solverforge --version")
  assert_file_contains(doc_page, "solverforge new solverforge-hospital --quiet")
  assert_file_contains(doc_page, "solverforge-ui = \"#{EXPECTED_UI_VERSION}\"")
  assert_file_contains(doc_page, "cli_version = \"#{EXPECTED_HOSPITAL_APP_CLI_VERSION}\"")
  assert_file_contains(doc_page, "target = \"SolverForge crates.io target\"")
  assert_file_contains(doc_page, "runtime_crate = \"solverforge\"")
  assert_file_contains(doc_page, "runtime_version = \"#{EXPECTED_RUNTIME_VERSION}\"")
  assert_file_contains(doc_page, "ui_crate = \"solverforge-ui\"")
  assert_file_contains(doc_page, "ui_version = \"#{EXPECTED_UI_VERSION}\"")
  assert_file_contains(doc_page, "HardSoftDecimalScore")
  assert_file_contains(doc_page, "current hospital model with `Employee`, `CareHub`,")
  assert_file_contains(doc_page, "employee_idx")
  assert_file_contains(doc_page, "data::list_demo_data()")
  assert_file_contains(doc_page, "[\"LARGE\"]")
  assert_file_contains(doc_page, "/jobs/{id}/events")
  assert_file_contains(doc_page, "static/app/main.mjs")

  assert_file_not_contains(doc_page, "local SolverForge surface")
  assert_file_not_contains(doc_page, "sibling checkouts")
  assert_file_not_contains(doc_page, "SolverForge local path target")
  assert_file_not_contains(doc_page, "path = \"../solverforge-rs")
  assert_file_not_contains(doc_page, "path = \"../solverforge-ui")

  assert_rendered_h1_count

  if cli_repo
    require_command("cargo")

    log "Building the CLI binary and checking the documented command surface"
    run_system("cargo", "build", "--quiet", "--manifest-path", File.join(cli_repo, "Cargo.toml"))
    cli_bin = File.join(cli_repo, "target/debug/solverforge")
    fail!("missing built CLI binary: #{cli_bin}") unless File.executable?(cli_bin)

    version_output = run_command(cli_bin, "--version")
    assert_text_contains(version_output, "CLI version: #{EXPECTED_CLI_VERSION}", "solverforge --version output")
    assert_text_contains(version_output, "Scaffold runtime target: SolverForge crate target #{EXPECTED_RUNTIME_VERSION}", "solverforge --version output")
    assert_text_contains(version_output, "Scaffold UI target: solverforge-ui #{EXPECTED_UI_VERSION}", "solverforge --version output")
    assert_text_contains(version_output, "Scaffold maps target: solverforge-maps #{EXPECTED_MAPS_VERSION}", "solverforge --version output")
    assert_text_contains(version_output, "Runtime source: crates.io: solverforge #{EXPECTED_RUNTIME_VERSION}", "solverforge --version output")
    assert_text_contains(version_output, "UI source: crates.io: solverforge-ui #{EXPECTED_UI_VERSION}", "solverforge --version output")
    assert_text_contains(version_output, "Maps source: crates.io: solverforge-maps #{EXPECTED_MAPS_VERSION}", "solverforge --version output")

    new_help = run_command(cli_bin, "new", "--help")
    assert_text_contains(new_help, "Usage: solverforge new [OPTIONS] <NAME>", "solverforge new --help")
    assert_text_contains(new_help, "--skip-git", "solverforge new --help")
    assert_text_contains(new_help, "--skip-readme", "solverforge new --help")

    log "Scaffolding a fresh app through the real CLI"
    scaffold_root = File.join(tmp_dir, "scaffold")
    FileUtils.mkdir_p(scaffold_root)
    run_system(cli_bin, "new", "solverforge-hospital", "--skip-git", "--skip-readme", "--quiet", chdir: scaffold_root)

    generated_app = File.join(scaffold_root, "solverforge-hospital")
    fail!("CLI did not create #{generated_app}") unless Dir.exist?(generated_app)

    assert_file_contains(File.join(generated_app, "solverforge.app.toml"), "cli_version = \"#{EXPECTED_CLI_VERSION}\"")
    assert_file_contains(File.join(generated_app, "solverforge.app.toml"), "target = \"solverforge #{EXPECTED_RUNTIME_VERSION}\"")
    assert_file_contains(File.join(generated_app, "solverforge.app.toml"), "runtime_source = \"crates.io: solverforge #{EXPECTED_RUNTIME_VERSION}\"")
    assert_file_contains(File.join(generated_app, "solverforge.app.toml"), "ui_source = \"crates.io: solverforge-ui #{EXPECTED_UI_VERSION}\"")
    assert_file_contains(File.join(generated_app, "Cargo.toml"), "solverforge = { version = \"#{EXPECTED_RUNTIME_VERSION}\", features = [\"serde\", \"console\", \"verbose-logging\"] }")
    assert_file_contains(File.join(generated_app, "Cargo.toml"), "solverforge-ui = { version = \"#{EXPECTED_UI_VERSION}\" }")
    assert_file_contains(File.join(generated_app, "Cargo.toml"), "solverforge-maps = { version = \"#{EXPECTED_MAPS_VERSION}\" }")
    fail!("fresh scaffold is missing static/app.js") unless File.file?(File.join(generated_app, "static/app.js"))

    run_system(cli_bin, "check", chdir: generated_app)
    routes = run_command(cli_bin, "routes", chdir: generated_app)
    routes_path = File.join(tmp_dir, "routes.txt")
    File.write(routes_path, routes)
    assert_file_contains(routes_path, "/demo-data")
    assert_file_contains(routes_path, "/jobs")
    assert_file_contains(routes_path, "/jobs/{id}/events")
  end

  if hospital_repo
    require_command("cargo")

    log "Checking concrete hospital source files"
    assert_file_contains(File.join(hospital_repo, "Cargo.toml"), "solverforge-ui = \"#{EXPECTED_UI_VERSION}\"")
    assert_file_contains(File.join(hospital_repo, "solverforge.app.toml"), "cli_version = \"#{EXPECTED_HOSPITAL_APP_CLI_VERSION}\"")
    assert_file_contains(File.join(hospital_repo, "solverforge.app.toml"), "target = \"SolverForge crates.io target\"")
    assert_file_contains(File.join(hospital_repo, "solverforge.app.toml"), "runtime_crate = \"solverforge\"")
    assert_file_contains(File.join(hospital_repo, "solverforge.app.toml"), "runtime_version = \"#{EXPECTED_RUNTIME_VERSION}\"")
    assert_file_contains(File.join(hospital_repo, "solverforge.app.toml"), "ui_crate = \"solverforge-ui\"")
    assert_file_contains(File.join(hospital_repo, "solverforge.app.toml"), "ui_version = \"#{EXPECTED_UI_VERSION}\"")
    assert_file_contains(File.join(hospital_repo, "src/domain/plan.rs"), "pub employee_idx: Option<usize>")
    assert_file_contains(File.join(hospital_repo, "src/domain/plan.rs"), "pub score: Option<HardSoftDecimalScore>")
    assert_file_contains(File.join(hospital_repo, "src/domain/employee.rs"), "pub struct Employee")
    assert_file_contains(File.join(hospital_repo, "src/domain/care_hub.rs"), "pub enum CareHub")
    assert_file_contains(File.join(hospital_repo, "src/data/data_seed/entrypoints.rs"), "pub fn list_demo_data() -> Vec<&'static str>")
    assert_file_contains(File.join(hospital_repo, "src/data/data_seed/entrypoints.rs"), "\"LARGE\"")
    assert_file_contains(File.join(hospital_repo, "src/api/routes.rs"), ".route(\"/demo-data\", get(list_demo_data))")
    assert_file_contains(File.join(hospital_repo, "src/api/routes.rs"), ".route(\"/jobs\", post(create_job))")
    assert_file_contains(File.join(hospital_repo, "src/api/routes.rs"), ".route(\"/jobs/{id}/events\", get(sse::events))")
    assert_file_contains(File.join(hospital_repo, "static/index.html"), "import { bootApp } from '/app/main.mjs';")
    fail!("hospital app is missing static/app/main.mjs") unless File.file?(File.join(hospital_repo, "static/app/main.mjs"))

    log "Booting solverforge-hospital and smoking the documented endpoints"
    port = free_port
    base_url = "http://127.0.0.1:#{port}"
    hospital_log = File.join(tmp_dir, "hospital.log")
    log_file = File.open(hospital_log, "w")
    server_pid = Process.spawn({ "PORT" => port.to_s }, "cargo", "run", "--quiet", "--release", "--bin", "solverforge-hospital", chdir: hospital_repo, out: log_file, err: log_file)
    log_file.close

    wait_for_http_ok("#{base_url}/health", max_attempts: 120)

    demo_data_path = File.join(tmp_dir, "demo-data.json")
    File.write(demo_data_path, http_get_body("#{base_url}/demo-data"))
    assert_json_file(demo_data_path) do |json|
      fail!("expected [\"LARGE\"]") unless json == ["LARGE"]
    end

    plan_path = File.join(tmp_dir, "plan.json")
    File.write(plan_path, http_get_body("#{base_url}/demo-data/LARGE"))
    assert_json_file(plan_path) do |json|
      fail!("expected employees array") unless json["employees"].is_a?(Array)
      fail!("expected shifts array") unless json["shifts"].is_a?(Array)
    end

    create_response = http_request(:post, "#{base_url}/jobs", body: File.read(plan_path), headers: { "Content-Type" => "application/json" })
    fail!("POST #{base_url}/jobs returned #{create_response.code}") unless create_response.is_a?(Net::HTTPSuccess)

    create_job_path = File.join(tmp_dir, "create-job.json")
    File.write(create_job_path, create_response.body)
    job_id = json_field(parse_json_file(create_job_path), "id").to_s
    fail!("job creation did not return an id") if job_id.empty?

    job_path = File.join(tmp_dir, "job.json")
    File.write(job_path, http_get_body("#{base_url}/jobs/#{job_id}"))
    assert_json_file(job_path) do |json|
      fail!("job summary missing lifecycleState") unless json["lifecycleState"].is_a?(String)
    end

    sse_raw = first_sse_data_payload("#{base_url}/jobs/#{job_id}/events")
    fail!("SSE endpoint did not produce a bootstrap payload") unless sse_raw

    sse_data = sse_raw.lines.find { |line| line.start_with?("data: ") }&.sub(/^data: /, "")
    fail!("SSE endpoint did not produce a bootstrap payload") if sse_data.nil? || sse_data.empty?

    sse_path = File.join(tmp_dir, "sse.json")
    File.write(sse_path, sse_data)
    assert_json_file(sse_path) do |json|
      fail!("sse payload missing eventType") unless json["eventType"].is_a?(String)
      fail!("sse payload missing lifecycleState") unless json["lifecycleState"].is_a?(String)
    end

    snapshot_path = File.join(tmp_dir, "snapshot.json")
    wait_for_json_endpoint("#{base_url}/jobs/#{job_id}/snapshot", snapshot_path, max_attempts: 120)
    snapshot_revision = json_field(parse_json_file(snapshot_path), "snapshotRevision").to_s
    fail!("snapshot endpoint did not return a snapshot revision") if snapshot_revision.empty?
    assert_json_file(snapshot_path) do |json|
      fail!("snapshot missing solution") unless json["solution"].is_a?(Hash)
    end

    analysis_response = http_request(:get, "#{base_url}/jobs/#{job_id}/analysis?snapshot_revision=#{URI.encode_www_form_component(snapshot_revision)}")
    fail!("GET analysis returned #{analysis_response.code}") unless analysis_response.is_a?(Net::HTTPSuccess)

    analysis_path = File.join(tmp_dir, "analysis.json")
    File.write(analysis_path, analysis_response.body)
    assert_json_file(analysis_path) do |json|
      fail!("analysis revision mismatch") unless json["snapshotRevision"].to_s == snapshot_revision
      fail!("analysis missing breakdown") unless json["analysis"].is_a?(Hash)
    end

    cancel_response = http_request(:post, "#{base_url}/jobs/#{job_id}/cancel")
    unless %w[202 409].include?(cancel_response.code)
      fail!("expected cancel to return 202 or 409, got #{cancel_response.code}")
    end

    lifecycle_state = nil
    60.times do
      File.write(job_path, http_get_body("#{base_url}/jobs/#{job_id}"))
      lifecycle_state = json_field(parse_json_file(job_path), "lifecycleState").to_s
      break if %w[COMPLETED CANCELLED FAILED].include?(lifecycle_state)

      sleep 1
    end

    unless %w[COMPLETED CANCELLED FAILED].include?(lifecycle_state)
      fail!("job never reached a terminal state after cancel; last lifecycleState was #{lifecycle_state}")
    end

    delete_response = http_request(:delete, "#{base_url}/jobs/#{job_id}")
    fail!("expected delete to return 204, got #{delete_response.code}") unless delete_response.code == "204"
  end

  log "All tutorial contract checks passed"
ensure
  if server_pid
    begin
      Process.kill("TERM", server_pid)
      Process.wait(server_pid)
    rescue Errno::ESRCH, Errno::ECHILD
      nil
    end
  end

  FileUtils.remove_entry(tmp_dir) if tmp_dir && Dir.exist?(tmp_dir)
end
