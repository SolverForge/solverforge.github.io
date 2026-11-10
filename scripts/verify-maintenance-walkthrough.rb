#!/usr/bin/env ruby
# frozen_string_literal: true

# Holds the maintenance walkthrough to what it teaches.
#
# The page is the source of truth: its command block is replayed, its Rust
# excerpts must come verbatim from the published fixture files, and its
# analysis table is the expected solve result. Its live-repair section is
# replayed too: its solver.toml goes into the app, a job is started, the page's
# breakdown is posted to that running job, and the repaired plan must keep the
# same job, absorb the breakdown, and reach the page's score. Nothing here
# skips: a missing tool or build is a failure, because a gate that can skip
# reports the same green as a pass.
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

EXPECTED_CLI_VERSION = "4.0.3"
EXPECTED_RUNTIME_VERSION = "0.26.0"
EXPECTED_UNIT_TESTS = 20
APP_NAME = "depot-maintenance"
APP_BINARY = "depot_maintenance"
SOLVE_TIMEOUT_SECONDS = 120
REPAIR_TIMEOUT_SECONDS = 120
REPAIR_SECTION = "Repair the Plan Live"
SOLVED_SCORE = [0, -100]

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

  log "Checking the live-repair section"
  repair_contract(page)
  routes = sources.fetch("src/api/routes.rs") { fail!("no src/api/routes.rs fixture for the breakdown route") }
  fail!("routes.rs fixture does not register the breakdown route") unless routes.include?(%(.route("/jobs/{id}/breakdowns", post(report_breakdown))))
  service = sources.fetch("src/solver/service.rs") { fail!("no src/solver/service.rs fixture for the problem-change pass-through") }
  fail!("service.rs fixture does not forward to SolverManager::add_problem_change") unless service.include?("MANAGER.add_problem_change(parse_job_id(id)?, change)")

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

# What the live-repair section teaches: the solver.toml a running job needs,
# the breakdown it posts, and the score the repaired plan reaches.
def repair_contract(page)
  text = section(page, REPAIR_SECTION)
  toml = fenced_blocks(text, "toml").first || fail!("#{REPAIR_SECTION} has no solver.toml block")
  fail!("#{REPAIR_SECTION} solver.toml must not set a time limit") if toml.match?(/spent_limit/)
  fail!("#{REPAIR_SECTION} solver.toml must declare its phases") unless toml.include?("[[phases]]")
  curl = fenced_blocks(text, "bash").join.gsub("\\\n", " ")
  body = curl[%r{--data '(\{[^']*\})'\s+localhost:7860/jobs/0/breakdowns}, 1] || fail!("#{REPAIR_SECTION} has no breakdown curl")
  breakdown = JSON.parse(body)
  %w[busIdx skill earliestDay dueDay].each { |key| fail!("breakdown body has no #{key}") unless breakdown.key?(key) }
  repaired = text[/The repaired plan settles at\s+`(-?\d+hard\/-?\d+soft)`/m, 1] || fail!("#{REPAIR_SECTION} states no repaired score")
  fail!("#{REPAIR_SECTION} must wait for the solved score first") unless text.include?("`bestScore` `0hard/-100soft`")
  fail!("#{REPAIR_SECTION} must show the change acknowledgement") unless text.include?(%(# {"jobId":"0","changeId":1}))
  { toml: toml, breakdown: breakdown, repaired: parse_score(repaired) }
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
def check_solution(solution, job_count: 20, loads: [5, 5, 5, 5])
  technicians = solution.fetch("technicians")
  jobs = solution.fetch("jobs")
  fail!("solved plan should hold #{job_count} jobs, found #{jobs.size}") unless jobs.size == job_count
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
  actual = jobs.group_by { |job| job["technician_idx"] }.transform_values(&:size)
  fail!("workload #{actual} is not the split #{loads}") unless actual.values.sort == loads.sort
end

def post_json(url, body)
  Net::HTTP.post(URI(url), body.nil? ? "" : JSON.generate(body), "Content-Type" => "application/json")
end

def stop_server(pid)
  Process.kill("TERM", pid)
  Process.wait(pid)
rescue Errno::ESRCH, Errno::ECHILD
  nil
end

def boot_server(binary, app, log_path)
  port = free_port
  pid = Process.spawn({ "PORT" => port.to_s }, binary, chdir: app, out: log_path, err: log_path)
  base_url = "http://127.0.0.1:#{port}"
  wait_for_health(base_url, pid, log_path)
  [pid, base_url]
end

# Polls the job until the block accepts its status or the deadline passes.
def wait_for_job(base_url, job_id, seconds, what)
  deadline = Time.now + seconds
  loop do
    status = get_json("#{base_url}/jobs/#{job_id}")
    return status if yield(status)
    fail!("#{what} within #{seconds}s; last status #{status["lifecycleState"]} #{status["bestScore"]}") if Time.now > deadline

    sleep 0.05
  end
end

def phase_types(snapshot)
  snapshot.fetch("telemetry").fetch("phases").map { |phase| phase["phaseType"] }
end

# Replays the live-repair section on the overlaid app: the page's solver.toml,
# one job, the page's breakdown posted to that running job, and the repaired
# plan checked independently of the app's score.
def check_repair(page, cli, app, cargo_env, binary, root, git_identity)
  contract = repair_contract(page)

  log "Writing the page's open-ended solver.toml and rebuilding"
  File.write(File.join(app, "solver.toml"), contract[:toml])
  run!(git_identity, [cli, "check"], chdir: app)
  run!(cargo_env, %w[cargo build --release], chdir: app)

  server_pid, base_url = boot_server(binary, app, File.join(root, "repair-server.log"))
  begin
    plan = Net::HTTP.get(URI("#{base_url}/demo-data/STANDARD"))
    response = Net::HTTP.post(URI("#{base_url}/jobs"), plan, "Content-Type" => "application/json")
    fail!("POST /jobs returned #{response.code}") unless response.is_a?(Net::HTTPSuccess)
    job_id = JSON.parse(response.body).fetch("id")

    log "Waiting for job #{job_id} to reach 0hard/-100soft before the breakdown"
    wait_for_job(base_url, job_id, SOLVE_TIMEOUT_SECONDS, "job never reached 0hard/-100soft") do |status|
      fail!("open-ended job stopped as #{status["lifecycleState"]}") unless status["lifecycleState"] == "SOLVING"
      status["bestScore"] && parse_score(status["bestScore"]) == SOLVED_SCORE
    end
    before = get_json("#{base_url}/jobs/#{job_id}/snapshot")
    fail!("pre-breakdown snapshot should hold 20 jobs") unless before.fetch("solution").fetch("jobs").size == 20
    check_solution(before.fetch("solution"))

    log "Posting the page's breakdown to running job #{job_id}"
    breakdown = contract[:breakdown]
    response = post_json("#{base_url}/jobs/#{job_id}/breakdowns", breakdown)
    fail!("POST /jobs/#{job_id}/breakdowns returned #{response.code}, not 202") unless response.code == "202"
    ack = JSON.parse(response.body)
    fail!("breakdown acknowledgement #{ack} does not name job #{job_id} and change 1") unless ack == { "jobId" => job_id, "changeId" => 1 }

    log "Waiting for the repaired plan"
    after = nil
    deadline = Time.now + REPAIR_TIMEOUT_SECONDS
    loop do
      after = get_json("#{base_url}/jobs/#{job_id}/snapshot")
      break if after.fetch("solution").fetch("jobs").size == 21 && after["bestScore"] && parse_score(after["bestScore"]) == contract[:repaired]
      fail!("repaired plan never reached #{contract[:repaired]}; last #{after["bestScore"]} with #{after["solution"]["jobs"].size} jobs") if Time.now > deadline

      sleep 0.05
    end

    log "Checking that the same job absorbed the breakdown without a restart"
    status = get_json("#{base_url}/jobs/#{job_id}")
    fail!("job #{job_id} should still be SOLVING after the repair, found #{status["lifecycleState"]}") unless status["lifecycleState"] == "SOLVING"
    second = Net::HTTP.get_response(URI("#{base_url}/jobs/#{job_id.to_i + 1}"))
    fail!("a second job exists (GET /jobs/#{job_id.to_i + 1} returned #{second.code}); the repair must not start a new solve") unless second.code == "404"
    unless after.fetch("snapshotRevision") > before.fetch("snapshotRevision")
      fail!("snapshot revision went from #{before["snapshotRevision"]} to #{after["snapshotRevision"]}; the job restarted")
    end
    unless after.fetch("telemetry").fetch("elapsedMs") >= before.fetch("telemetry").fetch("elapsedMs")
      fail!("job clock went backwards across the repair; the job restarted")
    end
    phases = phase_types(after)
    first_search = phases.index("Local Search") || fail!("telemetry has no local search before the repair: #{phases}")
    unless phases[(first_search + 1)..].include?("Construction Heuristic")
      fail!("telemetry shows no construction pass after local search, so the change was never applied: #{phases}")
    end

    log "Re-deriving the repaired plan's feasibility from the snapshot"
    solution = after.fetch("solution")
    check_solution(solution, job_count: 21, loads: [6, 5, 5, 5])
    added = solution.fetch("jobs").last
    expected = { "bus_idx" => breakdown["busIdx"], "skill" => breakdown["skill"], "earliest_day" => breakdown["earliestDay"], "due_day" => breakdown["dueDay"] }
    expected.each do |key, value|
      fail!("breakdown job #{added["id"]} has #{key} #{added[key].inspect}, not #{value.inspect}") unless added[key] == value
    end
    original = JSON.parse(plan).fetch("jobs").map { |job| job["id"] }
    fail!("the repair dropped or renamed original jobs") unless solution.fetch("jobs").first(20).map { |job| job["id"] } == original

    log "Cancelling job #{job_id}; a cancelled job must refuse further changes"
    fail!("cancel returned an error") unless post_json("#{base_url}/jobs/#{job_id}/cancel", nil).is_a?(Net::HTTPSuccess)
    wait_for_job(base_url, job_id, 30, "job never reached CANCELLED") { |current| current["lifecycleState"] == "CANCELLED" }
    late = post_json("#{base_url}/jobs/#{job_id}/breakdowns", breakdown)
    fail!("a cancelled job accepted a breakdown (#{late.code}), expected 409") unless late.code == "409"
  ensure
    stop_server(server_pid)
  end
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

    log "Checking the overlaid project with solverforge check"
    run!(git_identity, [cli, "check"], chdir: app)

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

    stop_server(server_pid)
    server_pid = nil
    check_repair(page, cli, app, cargo_env, binary, root, git_identity)
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
  log "Walkthrough contract passed: replayed, tested, solved to 0hard/-100soft, repaired live"
end
