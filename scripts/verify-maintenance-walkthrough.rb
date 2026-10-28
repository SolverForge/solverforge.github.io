#!/usr/bin/env ruby
# frozen_string_literal: true

# Holds the maintenance walkthrough to what it teaches.
#
# The page is the source of truth: its command block is replayed, its Rust
# excerpts must come verbatim from the published fixture files, and its
# analysis table is the expected solve result. Nothing here skips: a missing
# tool or build is a failure, because a gate that can skip reports the same
# green as a pass.
#
#   ruby scripts/verify-maintenance-walkthrough.rb            # static + live
#   ruby scripts/verify-maintenance-walkthrough.rb --static   # page/fixture contract only
#
# The live run needs `solverforge` (or SOLVERFORGE_BIN) and cargo.

require "fileutils"
require "json"
require "net/http"
require "open3"
require "set"
require "shellwords"
require "socket"
require "tmpdir"
require "uri"

SITE_ROOT = File.expand_path("..", __dir__)
PAGE = File.join(SITE_ROOT, "src/docs/getting-started/maintenance-planning-with-the-agent-skill.md")
PAGE_URL = "/docs/getting-started/maintenance-planning-with-the-agent-skill/"
RENDERED = File.join(SITE_ROOT, "output", PAGE_URL, "index.html")
FIXTURES = File.join(SITE_ROOT, "scripts/fixtures/maintenance-walkthrough")
PROMPT = File.join(FIXTURES, "prompt.md")

EXPECTED_CLI_VERSION = "3.7.1"
EXPECTED_RUNTIME_VERSION = "0.23.0"
EXPECTED_UNIT_TESTS = 20
APP_NAME = "depot-maintenance"
APP_BINARY = "depot_maintenance"
SOLVE_TIMEOUT_SECONDS = 120

def log(message)
  puts "[verify-maintenance-walkthrough] #{message}"
end

def fail!(message)
  warn "[verify-maintenance-walkthrough] ERROR: #{message}"
  exit 1
end

def read(path)
  fail!("missing file: #{path.delete_prefix("#{SITE_ROOT}/")}") unless File.file?(path)
  File.read(path)
end

def assert_contains(path, needle)
  fail!("#{path.delete_prefix("#{SITE_ROOT}/")} is missing: #{needle}") unless read(path).include?(needle)
end

# Fenced blocks of one language, in page order.
def fenced_blocks(text, language)
  text.scan(/^```#{Regexp.escape(language)}\n(.*?)^```$/m).map(&:first)
end

def section(text, heading)
  lines = text.lines
  start = lines.index("## #{heading}\n") || fail!("page has no section: #{heading}")
  body = []
  fenced = false
  lines[(start + 1)..].each do |line|
    fenced = !fenced if line.start_with?("```")
    break if !fenced && line.start_with?("## ")

    body << line
  end
  body.join
end

# Rows of the first Markdown table in a section, without header and divider.
def table_rows(text)
  text.lines.map(&:strip).select { |line| line.start_with?("|") }.drop(2).map do |line|
    line.split("|").map(&:strip).reject(&:empty?)
  end
end

def fixture_sources
  Dir.glob(File.join(FIXTURES, "src/**/*.rs")).sort.to_h do |path|
    [path.delete_prefix("#{FIXTURES}/"), File.read(path)]
  end
end

def page_commands(text)
  block = fenced_blocks(section(text, "Scaffold and Grow the App"), "bash").first
  fail!("Scaffold and Grow the App has no bash block") unless block
  block.lines.map(&:strip).reject { |line| line.empty? || line.start_with?("#") }
end

def check_static
  page = read(PAGE)
  sources = fixture_sources
  fail!("no fixture sources under #{FIXTURES}") if sources.empty?

  log "Checking the published prompt"
  prompt = read(PROMPT).strip
  text_blocks = fenced_blocks(section(page, "Describe the Problem"), "text").map(&:strip)
  fail!("page prompt differs from #{PROMPT.delete_prefix("#{SITE_ROOT}/")}") unless text_blocks.include?(prompt)

  log "Checking every Rust excerpt against the fixture files"
  excerpts = fenced_blocks(page, "rust")
  fail!("page has no Rust excerpts") if excerpts.empty?
  excerpts.each_with_index do |excerpt, index|
    next if sources.values.any? { |source| source.include?(excerpt) }

    fail!("Rust excerpt #{index + 1} is not verbatim in any fixture file:\n#{excerpt}")
  end
  log "#{excerpts.size} Rust excerpts match fixture source"

  log "Checking the complete-source table against the fixture set"
  listed = table_rows(section(page, "Complete Source")).map { |row| row.first.delete("`") }
  fail!("complete-source table lists duplicates") unless listed.uniq.size == listed.size
  unless listed.to_set == sources.keys.to_set
    fail!("complete-source table #{listed.sort} does not match fixtures #{sources.keys.sort}")
  end

  log "Checking the command block"
  commands = page_commands(page)
  fail!("first command must scaffold the API shell") unless commands.first == "solverforge new #{APP_NAME} --shell api"
  fail!("second command must enter the app") unless commands[1] == "cd #{APP_NAME}"
  fail!("command block must end with solverforge check") unless commands.last == "solverforge check"
  commands.drop(2).each do |command|
    fail!("unexpected command in walkthrough block: #{command}") unless command.start_with?("solverforge ")
  end
  sources.each_key do |path|
    next unless path.start_with?("src/constraints/")

    name = File.basename(path, ".rs")
    unless commands.any? { |command| command.start_with?("solverforge generate constraint #{name} ") }
      fail!("fixture #{path} has no generate constraint command on the page")
    end
  end

  log "Checking version and result claims"
  assert_contains(PAGE, "`solverforge-cli #{EXPECTED_CLI_VERSION}`, which scaffolds `solverforge #{EXPECTED_RUNTIME_VERSION}`")
  assert_contains(PAGE, "runs the #{EXPECTED_UNIT_TESTS} unit tests")
  assert_contains(PAGE, "`bestScore` `0hard/-100soft`")
  assert_contains(PAGE, "git clone https://github.com/SolverForge/solverforge-cli")
  assert_contains(PAGE, "./scripts/install-skill --agent claude")
  rows = table_rows(section(page, "Solve It"))
  fail!("Solve It analysis table must name every constraint fixture") unless rows.map { |row| row.first.delete("`") }.to_set ==
    sources.keys.select { |path| path.start_with?("src/constraints/") }.map { |path| File.basename(path, ".rs") }.to_set

  log "Checking onboarding wiring"
  assert_contains(File.join(SITE_ROOT, "src/index.md"), %(href="<%= relative_url '/docs/solverforge-cli/agent-skill/' %>" data-home-primary-cta))
  assert_contains(File.join(SITE_ROOT, "src/index.md"), "relative_url '#{PAGE_URL}'")
  agent_skill = File.join(SITE_ROOT, "src/docs/solverforge-cli/agent-skill.md")
  assert_contains(agent_skill, "## Quick Start")
  assert_contains(agent_skill, "git clone https://github.com/SolverForge/solverforge-cli")
  assert_contains(agent_skill, PAGE_URL)
  hub = File.join(SITE_ROOT, "src/docs/getting-started/index.md")
  assert_contains(hub, %(title: "1. Install the Agent Skill"))
  assert_contains(hub, PAGE_URL)
  nav = read(File.join(SITE_ROOT, "src/_data/docs_nav.yml"))
  getting_started = nav[/- title: Getting Started\n.*?(?=\n  - title: )/m] || fail!("docs nav has no Getting Started section")
  first_child = getting_started[/children:\n\s+- title: ([^\n]+)/, 1]
  fail!("Getting Started nav must open with the agent skill, found #{first_child.inspect}") unless first_child == "Install the Agent Skill"
  fail!("Getting Started nav is missing the walkthrough") unless getting_started.include?("href: #{PAGE_URL}")
  assert_contains(File.join(SITE_ROOT, "src/_components/shared/search_surface.rb"), PAGE_URL)

  log "Checking the rendered page"
  fail!("rendered page missing at #{RENDERED.delete_prefix("#{SITE_ROOT}/")}; run `make build` first") unless File.file?(RENDERED)
  h1_count = File.read(RENDERED).scan(/<h1(?:\s|>)/i).size
  fail!("rendered walkthrough should have exactly one H1, found #{h1_count}") unless h1_count == 1

  page
end

def command?(name)
  ENV.fetch("PATH", "").split(File::PATH_SEPARATOR).any? { |dir| File.executable?(File.join(dir, name)) }
end

def cli_binary
  configured = ENV["SOLVERFORGE_BIN"]
  return configured if configured && File.executable?(configured)
  fail!("SOLVERFORGE_BIN is not executable: #{configured}") if configured && !configured.empty?
  return "solverforge" if command?("solverforge")

  fail!("solverforge-cli #{EXPECTED_CLI_VERSION} is required: cargo install solverforge-cli --version #{EXPECTED_CLI_VERSION} --locked, or set SOLVERFORGE_BIN")
end

def run!(env, argv, chdir:)
  output, status = Open3.capture2e(env, *argv, chdir: chdir)
  fail!("command failed in #{chdir}: #{argv.shelljoin}\n#{output}") unless status.success?
  output
end

def free_port
  server = TCPServer.new("127.0.0.1", 0)
  server.addr[1]
ensure
  server&.close
end

def get_json(url)
  response = Net::HTTP.get_response(URI(url))
  fail!("GET #{url} returned #{response.code}") unless response.is_a?(Net::HTTPSuccess)
  JSON.parse(response.body)
end

def wait_for_health(base_url, server_pid, log_path)
  180.times do
    if Process.waitpid(server_pid, Process::WNOHANG)
      fail!("app exited before it became healthy:\n#{File.read(log_path)}")
    end
    return if Net::HTTP.get_response(URI("#{base_url}/health")).is_a?(Net::HTTPSuccess)
  rescue SystemCallError
    nil
  ensure
    sleep 1
  end
  fail!("app never answered /health")
end

def parse_score(score)
  match = score.to_s.match(/\A(-?\d+)hard\/(-?\d+)soft\z/) || fail!("unparseable score #{score.inspect}")
  [match[1].to_i, match[2].to_i]
end

# An independent check of the solved plan. It re-derives every hard rule and
# the lateness and balance claims from the raw solution instead of trusting the
# app's own score.
def check_solution(solution)
  technicians = solution.fetch("technicians")
  jobs = solution.fetch("jobs")
  fail!("solved plan should hold 20 jobs, found #{jobs.size}") unless jobs.size == 20
  fail!("solved plan should hold 4 technicians, found #{technicians.size}") unless technicians.size == 4
  fail!("solved plan should hold 12 buses, found #{solution.fetch("buses").size}") unless solution.fetch("buses").size == 12

  jobs.each do |job|
    tech, day = job["technician_idx"], job["day"]
    fail!("#{job["id"]} is unassigned") if tech.nil? || day.nil?
    fail!("#{job["id"]} lands on day #{day}, outside 0..9") unless (0..9).cover?(day)
    fail!("#{job["id"]} goes to a technician without #{job["skill"]}") unless technicians.fetch(tech)["skills"].include?(job["skill"])
    fail!("#{job["id"]} is scheduled before its parts arrive") if day < job["earliest_day"]
    fail!("#{job["id"]} is late") if day > job["due_day"]
  end
  jobs.group_by { |job| [job["technician_idx"], job["day"]] }.each do |(tech, day), clash|
    fail!("technician #{tech} has #{clash.size} jobs on day #{day}") if clash.size > 1
  end
  jobs.group_by { |job| job["day"] }.each do |day, on_day|
    buses = on_day.map { |job| job["bus_idx"] }.uniq.size
    fail!("day #{day} has #{buses} buses in the workshop") if buses > 2
  end
  loads = jobs.group_by { |job| job["technician_idx"] }.transform_values(&:size)
  fail!("workload is not 5 per technician: #{loads}") unless loads.size == 4 && loads.values.all?(5)
end

def check_live(page)
  fail!("cargo is required for the live walkthrough check") unless command?("cargo")
  cli = cli_binary

  version = run!({}, [cli, "--version"], chdir: SITE_ROOT)
  ["CLI version: #{EXPECTED_CLI_VERSION}", "Scaffold runtime target: SolverForge crate target #{EXPECTED_RUNTIME_VERSION}"].each do |needle|
    fail!("solverforge --version is missing #{needle.inspect}:\n#{version}") unless version.include?(needle)
  end

  root = Dir.mktmpdir("solverforge-maintenance-walkthrough.")
  server_pid = nil
  begin
    app = File.join(root, APP_NAME)
    git_identity = {
      "GIT_AUTHOR_NAME" => "walkthrough", "GIT_AUTHOR_EMAIL" => "walkthrough@localhost",
      "GIT_COMMITTER_NAME" => "walkthrough", "GIT_COMMITTER_EMAIL" => "walkthrough@localhost"
    }

    log "Replaying the page's command block with #{cli}"
    page_commands(page).each do |command|
      next if command == "cd #{APP_NAME}"

      argv = Shellwords.split(command)
      argv[0] = cli
      run!(git_identity, argv, chdir: Dir.exist?(app) ? app : root)
    end

    app_toml = read(File.join(app, "solverforge.app.toml"))
    fail!("generated app does not record cli_version #{EXPECTED_CLI_VERSION}") unless app_toml.include?(%(cli_version = "#{EXPECTED_CLI_VERSION}"))
    fail!("generated app does not target solverforge #{EXPECTED_RUNTIME_VERSION}") unless app_toml.include?(%(target = "solverforge #{EXPECTED_RUNTIME_VERSION}"))
    fail!("generated solver.toml no longer stops at the 30 seconds the page states") unless read(File.join(app, "solver.toml")).include?("seconds_spent_limit = 30")

    log "Overlaying the published fixture files"
    fixture_sources.each do |relative, source|
      target = File.join(app, relative)
      fail!("fixture #{relative} does not replace a generated file") unless File.file?(target) || relative == "src/data/depot.rs"
      File.write(target, source)
    end

    cargo_env = { "CARGO_TARGET_DIR" => ENV.fetch("SOLVERFORGE_WALKTHROUGH_TARGET_DIR", File.join(root, "target")) }

    log "Running the app's tests"
    test_output = run!(cargo_env, %w[cargo test --release], chdir: app)
    passed = test_output.scan(/test result: ok\. (\d+) passed/).flatten.map(&:to_i).sum
    fail!("expected #{EXPECTED_UNIT_TESTS} passing tests, found #{passed}\n#{test_output}") unless passed == EXPECTED_UNIT_TESTS

    log "Building and booting the API shell"
    run!(cargo_env, %w[cargo build --release], chdir: app)
    binary = File.join(cargo_env["CARGO_TARGET_DIR"], "release", APP_BINARY)
    fail!("missing release binary #{binary}") unless File.executable?(binary)
    port = free_port
    base_url = "http://127.0.0.1:#{port}"
    server_log = File.join(root, "server.log")
    server_pid = Process.spawn({ "PORT" => port.to_s }, binary, chdir: app, out: server_log, err: server_log)
    wait_for_health(base_url, server_pid, server_log)

    plan = Net::HTTP.get(URI("#{base_url}/demo-data/STANDARD"))
    response = Net::HTTP.post(URI("#{base_url}/jobs"), plan, "Content-Type" => "application/json")
    fail!("POST /jobs returned #{response.code}") unless response.is_a?(Net::HTTPSuccess)
    job_id = JSON.parse(response.body).fetch("id")

    log "Solving job #{job_id}"
    job = nil
    SOLVE_TIMEOUT_SECONDS.times do
      job = get_json("#{base_url}/jobs/#{job_id}")
      break if %w[COMPLETED CANCELLED FAILED].include?(job["lifecycleState"])

      sleep 1
    end
    fail!("job never completed; last state #{job && job["lifecycleState"]}") unless job && job["lifecycleState"] == "COMPLETED"
    fail!("bestScore #{job["bestScore"]} is not the page's 0hard/-100soft") unless parse_score(job["bestScore"]) == [0, -100]

    log "Comparing the analysis with the page's table"
    expected = table_rows(section(page, "Solve It")).to_h { |name, score| [name.delete("`"), parse_score(score.delete("`"))] }
    analysis = get_json("#{base_url}/jobs/#{job_id}/analysis").fetch("analysis").fetch("constraints")
    actual = analysis.to_h { |constraint| [constraint["name"], parse_score(constraint["score"])] }
    fail!("analysis #{actual} does not match the page table #{expected}") unless actual == expected

    log "Re-deriving the plan's feasibility from the snapshot"
    check_solution(get_json("#{base_url}/jobs/#{job_id}/snapshot").fetch("solution"))
  ensure
    if server_pid
      begin
        Process.kill("TERM", server_pid)
        Process.wait(server_pid)
      rescue Errno::ESRCH, Errno::ECHILD
        nil
      end
    end
    FileUtils.remove_entry(root) if root && Dir.exist?(root)
  end
end

page = check_static
if ARGV.include?("--static")
  log "Static walkthrough contract passed"
else
  check_live(page)
  log "Walkthrough contract passed: replayed, tested, solved to 0hard/-100soft"
end
