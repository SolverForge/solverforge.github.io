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
EXPECTED_CLI_VERSION = "2.0.1"
EXPECTED_RUNTIME_VERSION = "0.9.1"
EXPECTED_UI_VERSION = "0.6.3"
EXPECTED_MAPS_VERSION = "2.1.3"

def log(message)
  puts "[verify-deliveries-tutorial] #{message}"
end

def fail!(message)
  warn "[verify-deliveries-tutorial] ERROR: #{message}"
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

def run_system(*argv, chdir: nil, env: {})
  options = {}
  options[:chdir] = chdir if chdir
  system(env, *argv, **options) || fail!("command failed: #{argv.join(" ")}")
end

def run_command(*argv, chdir: nil, env: {})
  options = {}
  options[:chdir] = chdir if chdir
  stdout, stderr, status = Open3.capture3(env, *argv, **options)
  fail!("command failed: #{argv.join(" ")}\n#{stderr}") unless status.success?

  stdout
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

def extract_first_sse_data(raw)
  event, separator, = raw.gsub("\r\n", "\n").partition("\n\n")
  return nil if separator.empty?

  data_lines = event.lines.filter_map do |line|
    next unless line.start_with?("data:")

    line.sub(/^data:\s?/, "").chomp
  end

  return nil if data_lines.empty?

  data_lines.join("\n")
end

def first_sse_data_payload(url, timeout_seconds: 10)
  uri = URI(url)
  raw = +""

  Timeout.timeout(timeout_seconds) do
    Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https", read_timeout: timeout_seconds) do |http|
      request = Net::HTTP::Get.new(uri)
      http.request(request) do |response|
        fail!("GET #{url} returned #{response.code}") unless response.is_a?(Net::HTTPSuccess)

        response.read_body do |chunk|
          raw << chunk
          payload = extract_first_sse_data(raw)
          return payload if payload
        end
      end
    end
  end

  extract_first_sse_data(raw)
rescue Timeout::Error
  extract_first_sse_data(raw)
end

def json_field(json, field)
  field.split(".").reduce(json) do |value, part|
    value.is_a?(Array) ? value.fetch(Integer(part)) : value.fetch(part)
  end
end

def assert_rendered_h1_count
  rendered_doc = File.join(SITE_ROOT, "output/docs/getting-started/solverforge-deliveries-use-case/index.html")

  unless File.file?(rendered_doc)
    log "Skipping rendered H1 check; build output not found at #{rendered_doc}"
    return
  end

  count = File.read(rendered_doc).scan(/<h1(?:\s|>)/i).size
  fail!("rendered deliveries tutorial should have exactly one H1, found #{count}") unless count == 1
end

def small_straight_line_plan(plan)
  plan = Marshal.load(Marshal.dump(plan))
  plan["routingMode"] = "straight_line"
  plan["deliveries"] = plan.fetch("deliveries").first(6)
  plan["vehicles"] = plan.fetch("vehicles").first(2).map do |vehicle|
    vehicle.merge("deliveryOrder" => [])
  end
  plan["viewState"] = {
    "timelineView" => "by_vehicle",
    "selectedVehicleId" => nil,
    "selectedDeliveryId" => nil,
    "preview" => nil
  }
  plan["score"] = nil
  plan
end

def wait_for_terminal_state(base_url, job_id, output_file, max_attempts: 60)
  lifecycle_state = nil

  max_attempts.times do
    File.write(output_file, http_get_body("#{base_url}/jobs/#{job_id}"))
    lifecycle_state = json_field(parse_json_file(output_file), "lifecycleState").to_s
    return lifecycle_state if %w[COMPLETED CANCELLED FAILED].include?(lifecycle_state)

    sleep 1
  end

  fail!("job never reached a terminal state; last lifecycleState was #{lifecycle_state}")
end

tmp_dir = Dir.mktmpdir("solverforge-deliveries-tutorial.")
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

  deliveries_repo = discover_repo("SOLVERFORGE_DELIVERIES_REPO", [
    File.join(SITE_ROOT, "../solverforge-deliveries"),
    File.join(SITE_ROOT, "../../solverforge-deliveries")
  ])

  if deliveries_repo
    log "Using deliveries repo: #{deliveries_repo}"
  else
    log "Skipping concrete deliveries repo checks; set SOLVERFORGE_DELIVERIES_REPO to enable them."
  end

  doc_page = File.join(SITE_ROOT, "src/docs/getting-started/solverforge-deliveries-use-case.md")
  hub_page = File.join(SITE_ROOT, "src/docs/getting-started/index.md")
  search_surface = File.join(SITE_ROOT, "src/_components/shared/search_surface.rb")

  log "Checking public copy and tutorial snippets"
  assert_file_contains(hub_page, "SolverForge Deliveries Use Case")
  assert_file_contains(search_surface, "Study list-variable vehicle routing")
  assert_file_contains(doc_page, "cargo install solverforge-cli --force")
  assert_file_contains(doc_page, "solverforge --version")
  assert_file_contains(doc_page, "solverforge new solverforge-deliveries --quiet")
  assert_file_contains(doc_page, "cd solverforge-deliveries")
  assert_file_contains(doc_page, "solverforge generate fact delivery")
  assert_file_contains(doc_page, "solverforge generate entity vehicle")
  assert_file_contains(doc_page, "solverforge generate variable delivery_order")
  assert_file_contains(doc_page, "solverforge generate constraint total_travel_time --unary --soft")
  assert_file_contains(doc_page, "solverforge generate data --mode stub")
  assert_file_contains(doc_page, "solverforge = { version = \"#{EXPECTED_RUNTIME_VERSION}\"")
  assert_file_contains(doc_page, "solverforge-ui = \"#{EXPECTED_UI_VERSION}\"")
  assert_file_contains(doc_page, "solverforge-maps = \"#{EXPECTED_MAPS_VERSION}\"")
  assert_file_contains(doc_page, "cli_version = \"#{EXPECTED_CLI_VERSION}\"")
  assert_file_contains(doc_page, "target = \"solverforge #{EXPECTED_RUNTIME_VERSION}\"")
  assert_file_contains(doc_page, "runtime_source = \"crates.io: solverforge #{EXPECTED_RUNTIME_VERSION}\"")
  assert_file_contains(doc_page, "ui_source = \"crates.io: solverforge-ui #{EXPECTED_UI_VERSION}\"")
  assert_file_contains(doc_page, "maps_source = \"crates.io: solverforge-maps #{EXPECTED_MAPS_VERSION}\"")
  assert_file_contains(doc_page, "Vehicle.delivery_order")
  assert_file_contains(doc_page, "list_clarke_wright")
  assert_file_contains(doc_page, "/jobs/{id}/routes")
  assert_file_contains(doc_page, "/recommendations/delivery-insertions")
  assert_file_contains(doc_page, "PHILADELPHIA")
  assert_file_contains(doc_page, "HARTFORD")
  assert_file_contains(doc_page, "FIRENZE")

  assert_file_not_contains(doc_page, "Local sibling checkouts")
  assert_file_not_contains(doc_page, "sibling local path dependencies")
  assert_file_not_contains(doc_page, "frozen crates.io-only sample")
  assert_file_not_contains(doc_page, "path = \"../solverforge-rs")
  assert_file_not_contains(doc_page, "path = \"../solverforge-ui")
  assert_file_not_contains(doc_page, "path = \"../solverforge-maps")
  assert_file_not_contains(doc_page, "runtime_source = \"path:")
  assert_file_not_contains(doc_page, "ui_source = \"path:")
  assert_file_not_contains(doc_page, "maps_source = \"path:")
  assert_file_not_contains(doc_page, "cd ~/")
  assert_file_not_contains(doc_page, "/srv/lab/dev/")
  assert_file_not_contains(doc_page, "solverforge generate solution plan")

  assert_rendered_h1_count

  if cli_repo
    require_command("cargo")

    log "Building the CLI binary and checking the documented scaffold surface"
    run_system("cargo", "build", "--quiet", "--manifest-path", File.join(cli_repo, "Cargo.toml"))
    cli_bin = File.join(cli_repo, "target/debug/solverforge")
    fail!("missing built CLI binary: #{cli_bin}") unless File.executable?(cli_bin)

    version_output = run_command(cli_bin, "--version")
    assert_text_contains(version_output, "CLI version: #{EXPECTED_CLI_VERSION}", "solverforge --version output")
    assert_text_contains(version_output, "Scaffold runtime target: SolverForge crate target #{EXPECTED_RUNTIME_VERSION}", "solverforge --version output")
    assert_text_contains(version_output, "Scaffold UI target: solverforge-ui #{EXPECTED_UI_VERSION}", "solverforge --version output")
    assert_text_contains(version_output, "Scaffold maps target: solverforge-maps #{EXPECTED_MAPS_VERSION}", "solverforge --version output")

    log "Scaffolding a fresh deliveries app through the real CLI"
    scaffold_root = File.join(tmp_dir, "scaffold")
    FileUtils.mkdir_p(scaffold_root)
    run_system(cli_bin, "new", "solverforge-deliveries", "--skip-git", "--skip-readme", "--quiet", chdir: scaffold_root)

    generated_app = File.join(scaffold_root, "solverforge-deliveries")
    fail!("CLI did not create #{generated_app}") unless Dir.exist?(generated_app)

    assert_file_contains(File.join(generated_app, "solverforge.app.toml"), "cli_version = \"#{EXPECTED_CLI_VERSION}\"")
    assert_file_contains(File.join(generated_app, "solverforge.app.toml"), "target = \"solverforge #{EXPECTED_RUNTIME_VERSION}\"")
    assert_file_contains(File.join(generated_app, "solverforge.app.toml"), "runtime_source = \"crates.io: solverforge #{EXPECTED_RUNTIME_VERSION}\"")
    assert_file_contains(File.join(generated_app, "solverforge.app.toml"), "ui_source = \"crates.io: solverforge-ui #{EXPECTED_UI_VERSION}\"")
    assert_file_contains(File.join(generated_app, "Cargo.toml"), "rust-version = \"1.95\"")
    assert_file_contains(File.join(generated_app, "Cargo.toml"), "solverforge = { version = \"#{EXPECTED_RUNTIME_VERSION}\", features = [\"serde\", \"console\", \"verbose-logging\"] }")
    assert_file_contains(File.join(generated_app, "Cargo.toml"), "solverforge-ui = { version = \"#{EXPECTED_UI_VERSION}\" }")
    assert_file_contains(File.join(generated_app, "Cargo.toml"), "solverforge-maps = { version = \"#{EXPECTED_MAPS_VERSION}\" }")
    fail!("fresh scaffold is missing static/app.js") unless File.file?(File.join(generated_app, "static/app.js"))

    log "Replaying the documented deliveries generator sequence"
    run_system(
      cli_bin,
      "generate",
      "fact",
      "delivery",
      "--field",
      "label:String",
      "--field",
      "kind:DeliveryKind",
      "--field",
      "lat:CoordValue",
      "--field",
      "lng:CoordValue",
      "--field",
      "demand:i32",
      "--field",
      "min_start_time:i64",
      "--field",
      "max_end_time:i64",
      "--field",
      "service_duration:i64",
      chdir: generated_app
    )
    run_system(
      cli_bin,
      "generate",
      "entity",
      "vehicle",
      "--field",
      "name:String",
      "--field",
      "capacity:i32",
      "--field",
      "home_lat:CoordValue",
      "--field",
      "home_lng:CoordValue",
      "--field",
      "departure_time:i64",
      chdir: generated_app
    )
    run_system(
      cli_bin,
      "generate",
      "variable",
      "delivery_order",
      "--entity",
      "Vehicle",
      "--kind",
      "list",
      "--elements",
      "deliveries",
      chdir: generated_app
    )
    run_system(cli_bin, "generate", "constraint", "all_deliveries_assigned", "--unary", "--hard", chdir: generated_app)
    run_system(cli_bin, "generate", "constraint", "vehicle_capacity", "--unary", "--hard", chdir: generated_app)
    run_system(cli_bin, "generate", "constraint", "delivery_time_windows", "--unary", "--hard", chdir: generated_app)
    run_system(cli_bin, "generate", "constraint", "total_travel_time", "--unary", "--soft", chdir: generated_app)
    run_system(cli_bin, "generate", "data", "--mode", "stub", chdir: generated_app)

    run_system(cli_bin, "check", chdir: generated_app)
    routes = run_command(cli_bin, "routes", chdir: generated_app)
    routes_path = File.join(tmp_dir, "routes.txt")
    File.write(routes_path, routes)
    assert_file_contains(routes_path, "/demo-data")
    assert_file_contains(routes_path, "/jobs")
    assert_file_contains(routes_path, "/jobs/{id}/events")
  end

  if deliveries_repo
    log "Checking concrete deliveries source files"
    assert_file_contains(File.join(deliveries_repo, "Cargo.toml"), "rust-version = \"1.95\"")
    assert_file_contains(File.join(deliveries_repo, "Cargo.toml"), "solverforge = { version = \"#{EXPECTED_RUNTIME_VERSION}\"")
    assert_file_contains(File.join(deliveries_repo, "Cargo.toml"), "solverforge-ui = \"#{EXPECTED_UI_VERSION}\"")
    assert_file_contains(File.join(deliveries_repo, "Cargo.toml"), "solverforge-maps = \"#{EXPECTED_MAPS_VERSION}\"")
    assert_file_not_contains(File.join(deliveries_repo, "Cargo.toml"), "path = \"../solverforge-rs")
    assert_file_not_contains(File.join(deliveries_repo, "Cargo.toml"), "path = \"../solverforge-ui")
    assert_file_not_contains(File.join(deliveries_repo, "Cargo.toml"), "path = \"../solverforge-maps")

    assert_file_contains(File.join(deliveries_repo, "solverforge.app.toml"), "cli_version = \"#{EXPECTED_CLI_VERSION}\"")
    assert_file_contains(File.join(deliveries_repo, "solverforge.app.toml"), "target = \"solverforge #{EXPECTED_RUNTIME_VERSION}\"")
    assert_file_contains(File.join(deliveries_repo, "solverforge.app.toml"), "runtime_source = \"crates.io: solverforge #{EXPECTED_RUNTIME_VERSION}\"")
    assert_file_contains(File.join(deliveries_repo, "solverforge.app.toml"), "ui_source = \"crates.io: solverforge-ui #{EXPECTED_UI_VERSION}\"")
    assert_file_contains(File.join(deliveries_repo, "solverforge.app.toml"), "maps_source = \"crates.io: solverforge-maps #{EXPECTED_MAPS_VERSION}\"")
    assert_file_not_contains(File.join(deliveries_repo, "solverforge.app.toml"), "path:")

    assert_file_contains(File.join(deliveries_repo, "README.md"), "published crates.io")
    assert_file_contains(File.join(deliveries_repo, "src/domain/mod.rs"), "solverforge::planning_model!")
    assert_file_contains(File.join(deliveries_repo, "src/domain/plan.rs"), "solver_toml = \"../../solver.toml\"")
    assert_file_contains(File.join(deliveries_repo, "src/domain/plan.rs"), "pub routing_mode: RoutingMode")
    assert_file_contains(File.join(deliveries_repo, "src/domain/plan.rs"), "pub score: Option<HardSoftScore>")
    assert_file_contains(File.join(deliveries_repo, "src/domain/delivery.rs"), "pub struct Delivery")
    assert_file_contains(File.join(deliveries_repo, "src/domain/delivery.rs"), "pub id: usize")
    assert_file_contains(File.join(deliveries_repo, "src/domain/vehicle.rs"), "#[planning_list_variable(")
    assert_file_contains(File.join(deliveries_repo, "src/domain/vehicle.rs"), "pub delivery_order: Vec<usize>")
    assert_file_contains(File.join(deliveries_repo, "src/data/data_seed/entrypoints.rs"), "\"PHILADELPHIA\"")
    assert_file_contains(File.join(deliveries_repo, "src/data/data_seed/entrypoints.rs"), "\"HARTFORD\"")
    assert_file_contains(File.join(deliveries_repo, "src/data/data_seed/entrypoints.rs"), "\"FIRENZE\"")
    assert_file_contains(File.join(deliveries_repo, "src/api/routes.rs"), ".route(\"/jobs/{id}/routes\", get(get_routes))")
    assert_file_contains(File.join(deliveries_repo, "src/api/routes.rs"), ".route(\"/jobs/{id}/events\", get(sse::events))")
    assert_file_contains(File.join(deliveries_repo, "src/api/routes.rs"), "\"/recommendations/delivery-insertions\"")
    assert_file_contains(File.join(deliveries_repo, "tests/api_contract.rs"), "mod catalog")
    assert_file_contains(File.join(deliveries_repo, "tests/api_contract/catalog.rs"), "demo_data_and_static_assets_match_current_contract")
    assert_file_contains(File.join(deliveries_repo, "tests/api_contract/jobs.rs"), "straight_line_job_emits_a_non_empty_snapshot_before_cancellation")
    assert_file_contains(File.join(deliveries_repo, "tests/api_contract/lifecycle.rs"), "jobs_lifecycle_snapshot_analysis_routes_and_delete_work")
    assert_file_contains(File.join(deliveries_repo, "tests/api_contract/sse.rs"), "sse_endpoint_bootstraps_typed_events")
    assert_file_contains(File.join(deliveries_repo, "tests/frontend_models.test.mjs"), "test")
    fail!("deliveries app is missing static/app/main.mjs") unless File.file?(File.join(deliveries_repo, "static/app/main.mjs"))
    fail!("deliveries app is missing static/generated/ui-model.json") unless File.file?(File.join(deliveries_repo, "static/generated/ui-model.json"))

    require_command("cargo")

    log "Booting solverforge-deliveries and smoking the documented endpoints"
    port = free_port
    base_url = "http://127.0.0.1:#{port}"
    deliveries_log = File.join(tmp_dir, "deliveries.log")
    log_file = File.open(deliveries_log, "w")
    server_pid = Process.spawn(
      { "PORT" => port.to_s },
      "cargo",
      "run",
      "--quiet",
      "--release",
      "--bin",
      "solverforge_deliveries",
      chdir: deliveries_repo,
      out: log_file,
      err: log_file
    )
    log_file.close

    wait_for_http_ok("#{base_url}/health", max_attempts: 120)

    demo_data_path = File.join(tmp_dir, "demo-data.json")
    File.write(demo_data_path, http_get_body("#{base_url}/demo-data"))
    assert_json_file(demo_data_path) do |json|
      fail!("expected delivery demo ids") unless json == %w[PHILADELPHIA HARTFORD FIRENZE]
    end

    plan_path = File.join(tmp_dir, "plan.json")
    plan = JSON.parse(http_get_body("#{base_url}/demo-data/HARTFORD"))
    File.write(plan_path, JSON.generate(plan))
    assert_json_file(plan_path) do |json|
      fail!("expected Hartford plan") unless json["name"] == "Hartford"
      fail!("expected deliveries array") unless json["deliveries"].is_a?(Array)
      fail!("expected vehicles array") unless json["vehicles"].is_a?(Array)
    end

    small_plan = small_straight_line_plan(plan)
    create_response = http_request(
      :post,
      "#{base_url}/jobs",
      body: JSON.generate(small_plan),
      headers: { "Content-Type" => "application/json" }
    )
    fail!("POST #{base_url}/jobs returned #{create_response.code}") unless create_response.is_a?(Net::HTTPSuccess)

    create_job_path = File.join(tmp_dir, "create-job.json")
    File.write(create_job_path, create_response.body)
    job_id = json_field(parse_json_file(create_job_path), "id").to_s
    fail!("job creation did not return an id") if job_id.empty?

    sse_data = first_sse_data_payload("#{base_url}/jobs/#{job_id}/events")
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

    routes_path = File.join(tmp_dir, "routes.json")
    wait_for_json_endpoint("#{base_url}/jobs/#{job_id}/routes?snapshot_revision=#{snapshot_revision}", routes_path, max_attempts: 60)
    assert_json_file(routes_path) do |json|
      fail!("routes revision mismatch") unless json["snapshotRevision"].to_s == snapshot_revision
      fail!("routes missing vehicles") unless json["vehicles"].is_a?(Array)
    end

    recommendation_response = http_request(
      :post,
      "#{base_url}/recommendations/delivery-insertions",
      body: JSON.generate({ "plan" => small_plan, "deliveryId" => 0, "limit" => 3 }),
      headers: { "Content-Type" => "application/json" }
    )
    fail!("POST delivery insertions returned #{recommendation_response.code}") unless recommendation_response.is_a?(Net::HTTPSuccess)

    recommendation_path = File.join(tmp_dir, "recommendations.json")
    File.write(recommendation_path, recommendation_response.body)
    assert_json_file(recommendation_path) do |json|
      fail!("recommendations missing candidates") unless json["candidates"].is_a?(Array)
    end

    cancel_response = http_request(:post, "#{base_url}/jobs/#{job_id}/cancel")
    unless %w[202 409].include?(cancel_response.code)
      fail!("expected cancel to return 202 or 409, got #{cancel_response.code}")
    end

    job_path = File.join(tmp_dir, "job.json")
    wait_for_terminal_state(base_url, job_id, job_path)

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
