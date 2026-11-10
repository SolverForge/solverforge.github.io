#!/usr/bin/env ruby
# frozen_string_literal: true

# Holds the hospital use-case page to what a reader gets by following it.
#
# The page is the source of truth. The static half checks the page's shape
# and the claims it can check without running anything. The live half replays
# both paths the page teaches with the published CLI:
#
#   1. the scaffold path: the page's shell blocks and complete files, in page
#      order, then `cargo build`, the page's run command, and a solve that must
#      complete, not FAIL, and reach the hard score the page states;
#   2. the finished example: `git clone` of the Hugging Face Space the page
#      names, the page's validation commands, the page's run command and a
#      solve, plus the page's facts (dependencies, metadata, excerpts, routes,
#      dataset size, constraint ids, file paths) read from that clone.
#
#   ruby scripts/verify-hospital-tutorial.rb            # static + live
#   ruby scripts/verify-hospital-tutorial.rb --static   # page contract only
#
# Nothing skips: a missing tool is a failure. See scripts/lib/tutorial_replay.rb
# for the cache and target-dir environment variables.

require "json"
require "set"
require "timeout"
require_relative "lib/tutorial_replay"

SITE_ROOT = File.expand_path("..", __dir__)
PAGE = File.join(SITE_ROOT, "src/docs/getting-started/solverforge-hospital-use-case.md")
PAGE_URL = "/docs/getting-started/solverforge-hospital-use-case/"
RENDERED = File.join(SITE_ROOT, "output", PAGE_URL, "index.html")

# The published artifacts this page documents.
CLI_VERSION = "4.0.3"
RUNTIME_VERSION = "0.26.0"
UI_VERSION = "0.9.0"
APP_VERSION = "3.0.3"
SPACE_URL = "https://huggingface.co/spaces/SolverForge/solverforge-hospital"

SCAFFOLD_SECTIONS = ["Getting Started", "Build the App from the Scaffold"].freeze
FINISHED_SECTIONS = ["Run the Finished Example", "Testing and Validation"].freeze
RUN_COMMAND = /\A(?:PORT=\d+\s+)?(?:solverforge server|make run|cargo run)\b/
KNOWN_TYPES = %w[String usize u32 u64 i32 i64 f64 bool BTreeSet Vec Option NaiveDate NaiveDateTime].freeze

def log(message)
  puts "[verify-hospital-tutorial] #{message}"
end

def fail!(message)
  warn "[verify-hospital-tutorial] ERROR: #{message}"
  exit 1
end

def read(path)
  fail!("missing file: #{path.delete_prefix("#{SITE_ROOT}/")}") unless File.file?(path)
  File.read(path)
end

PROBLEMS = []

# Records a page defect; the static half reports every one before it fails.
def problem!(message)
  PROBLEMS << message unless PROBLEMS.include?(message)
  nil
end

def assert_contains(path, needle)
  problem!("#{path.delete_prefix("#{SITE_ROOT}/")} is missing: #{needle}") unless read(path).include?(needle)
end

def page_steps(page, sections)
  sections.flat_map { |heading| TutorialReplay.steps(TutorialReplay.section(page, heading)) }
end

# The static half records a missing section and carries on with the rest.
def static_steps(page, sections)
  sections.flat_map do |heading|
    TutorialReplay.steps(TutorialReplay.section(page, heading))
  rescue TutorialReplay::Failure => e
    problem!(e.message)
    []
  end
end

# Splits replay steps into the commands to replay and the page's run command.
def split_run(steps, label)
  runs = steps.select { |step| step.shell? && step.text.match?(RUN_COMMAND) }
  fail!("#{label} path shows no run command (solverforge server / make run / cargo run)") if runs.empty?
  [steps - runs, runs.last.text]
end

def skip_reason(command)
  "the gate installs solverforge-cli #{CLI_VERSION} into its cache" if command.start_with?("cargo install solverforge-cli")
end

# Rows of the first Markdown table in `text`, without header and divider.
def table_rows(text)
  text.lines.map(&:strip).select { |line| line.start_with?("|") }.drop(2).map do |line|
    line.split("|").map(&:strip).reject(&:empty?)
  end
end

def rule_ids(page)
  table_rows(TutorialReplay.section(page, "The Problem We're Solving")).map { |row| row.first.delete("`") }
end

# ------------------------------------------------------------------ static half

def check_static
  page = read(PAGE)
  TutorialReplay.fenced_blocks(page)

  log "Checking the install and version claims"
  install = static_steps(page, ["Getting Started"]).select(&:shell?).map(&:text)
  problem!("Getting Started must install the CLI with `cargo install solverforge-cli --locked`") unless install.include?("cargo install solverforge-cli --locked")
  assert_contains(PAGE, "`solverforge-cli #{CLI_VERSION}` scaffolds `solverforge #{RUNTIME_VERSION}`")
  assert_contains(PAGE, "solverforge-hospital@#{APP_VERSION}")

  log "Checking the scaffold path"
  steps = static_steps(page, SCAFFOLD_SECTIONS)
  commands = steps.select(&:shell?).map(&:text)
  files = steps.select(&:file?).to_h { |step| [step.path, step.text] }
  new_command = commands.find { |command| command.start_with?("solverforge new ") }
  if new_command
    app_dir = new_command.split[2]
    problem!("scaffold path must `cd #{app_dir}` right after `#{new_command}`") unless commands[commands.index(new_command) + 1] == "cd #{app_dir}"
  else
    problem!("scaffold path has no `solverforge new`")
  end
  problem!("scaffold path must not clone into the scaffold") if commands.any? { |command| command.start_with?("git clone") }
  problem!("scaffold path shows no run command") unless steps.any? { |step| step.shell? && step.text.match?(RUN_COMMAND) }

  commands.grep(/\Asolverforge generate (?:fact|entity) /).each do |command|
    fields = command.scan(/--field\s+"?([a-z_]+):([^"\s]+)"?/)
    duplicates = fields.map(&:first) & %w[id name]
    problem!("`#{command[0, 60]}...` passes built-in field(s) #{duplicates.join(", ")}; the CLI adds id and name itself") if duplicates.any?
    fields.flat_map { |_, type| type.scan(/[A-Z]\w*/) }.uniq.each do |type|
      next if KNOWN_TYPES.include?(type)

      defined = files.any? { |path, body| path.start_with?("src/domain/") && body.match?(/pub (?:enum|struct) #{type}\b/) }
      problem!("field type #{type} is never defined in a page file under src/domain/") unless defined
    end
  end

  generated = commands.grep(/\Asolverforge generate constraint /).map { |command| command.split[3] }
  problem!("scaffold path generates no constraints") if generated.empty?
  generated.each do |name|
    path = "src/constraints/#{name}.rs"
    problem!("generated constraint #{name} has no complete #{path} on the page; its stub panics on solve") unless files.key?(path)
  end
  files.each do |path, body|
    problem!("#{path} on the page still panics: #{body[/.*(?:panic!|todo!|unimplemented!).*/]}") if body.match?(/\b(?:panic|todo|unimplemented)!\(/)
  end
  domain_modules = files.keys.grep(%r{\Asrc/domain/(\w+)\.rs\z}).map { |path| File.basename(path, ".rs") } - ["mod"]
  if domain_modules.any?
    manifest = files["src/domain/mod.rs"]
    if manifest
      domain_modules.each { |name| problem!("src/domain/mod.rs on the page does not declare mod #{name}") unless manifest.include?("mod #{name};") }
    else
      problem!("the page adds #{domain_modules.join(", ")} but shows no complete src/domain/mod.rs")
    end
  end
  log "#{commands.size} scaffold commands, #{files.size} page files, #{generated.size} generated constraints"

  custom = static_steps(page, ["Making Your First Customization"])
  custom_files = custom.select(&:file?).to_h { |step| [step.path, step.text] }
  custom.select(&:shell?).map(&:text).grep(/\Asolverforge generate constraint /).each do |command|
    path = "src/constraints/#{command.split[3]}.rs"
    problem!("Making Your First Customization generates #{command.split[3]} but shows no complete #{path}") unless custom_files.key?(path)
  end
  custom_files.each do |path, body|
    problem!("#{path} on the page still panics") if body.match?(/\b(?:panic|todo|unimplemented)!\(/)
  end

  log "Checking the finished-example path"
  finished = static_steps(page, FINISHED_SECTIONS)
  finished_commands = finished.select(&:shell?).map(&:text)
  problem!("finished-example path must clone #{SPACE_URL}") unless finished_commands.include?("git clone #{SPACE_URL}")
  problem!("finished-example path must enter the clone") unless finished_commands.include?("cd solverforge-hospital")
  if finished_commands.include?("make test")
    install_index = finished_commands.index("make install-e2e")
    problem!("`make install-e2e` must come before `make test` in a standalone clone") unless install_index && install_index < finished_commands.index("make test")
  end
  problem!("finished-example path shows no run command") unless finished.any? { |step| step.shell? && step.text.match?(RUN_COMMAND) }

  log "Checking the rule table"
  ids = begin
    rule_ids(page)
  rescue TutorialReplay::Failure => e
    problem!(e.message)
    []
  end
  problem!("rule table must list constraint module ids, found #{ids.inspect}") unless ids.any? && ids.all? { |id| id.match?(/\A[a-z_]+\z/) }
  problem!("the scaffold path generates #{generated.sort}, the rule table lists #{ids.sort}") unless generated.to_set == ids.to_set

  log "Checking internal docs links"
  page.scan(%r{\]\((/docs/[^)#\s]+)}).flatten.uniq.each do |href|
    slug = href.delete_prefix("/").delete_suffix("/")
    candidates = ["src/#{slug}.md", "src/#{slug}/index.md", "src/#{slug}/_index.md"].map { |path| File.join(SITE_ROOT, path) }
    problem!("page links #{href}, which has no source page") unless candidates.any? { |path| File.file?(path) }
  end

  log "Checking onboarding wiring"
  assert_contains(File.join(SITE_ROOT, "src/index.md"), "Compare every use case")
  assert_contains(File.join(SITE_ROOT, "src/docs/getting-started/index.md"), %(title: "SolverForge Hospital Use Case"))
  assert_contains(File.join(SITE_ROOT, "src/_components/shared/search_surface.rb"), PAGE_URL)
  nav = read(File.join(SITE_ROOT, "src/_data/docs_nav.yml"))
  anchors = page.lines.select { |line| line.start_with?("## ") }.map { |line| line.strip.delete_prefix("## ").downcase.gsub(/[^a-z0-9 -]/, "").tr(" ", "-") }
  nav.scan(/#{Regexp.escape(PAGE_URL)}#([\w-]+)/).flatten.each do |anchor|
    problem!("docs nav links ##{anchor}, which is no H2 on the page") unless anchors.include?(anchor)
  end

  if File.file?(RENDERED)
    h1_count = File.read(RENDERED).scan(/<h1(?:\s|>)/i).size
    problem!("rendered page should have exactly one H1, found #{h1_count}") unless h1_count == 1
  end

  fail!("#{PROBLEMS.size} page problem(s):\n- #{PROBLEMS.join("\n- ")}") if PROBLEMS.any?
  page
end

# -------------------------------------------------------------------- live half

def toml_block(page, heading)
  TutorialReplay.fenced_blocks(TutorialReplay.section(page, heading)).find { |block| block.language == "toml" }&.body ||
    fail!("#{heading} has no toml block")
end

def normalized(text)
  text.lines.map(&:strip).reject { |line| line.empty? || line.start_with?("#") }
end

def contiguous?(haystack, needle)
  return false if needle.empty?

  haystack.each_cons(needle.size).any? { |window| window == needle }
end

def check_clone_facts(page, clone)
  log "Comparing the page's facts with the clone"
  cargo = read(File.join(clone, "Cargo.toml"))
  fail!("clone is not solverforge-hospital #{APP_VERSION}") unless cargo.include?(%(version = "#{APP_VERSION}"))
  deps = normalized(toml_block(page, "Keep the Published Dependency Shape"))
  fail!("page dependency block is not the clone's Cargo.toml [dependencies]") unless contiguous?(normalized(cargo), deps)
  meta = normalized(toml_block(page, "Align App Metadata"))
  fail!("page app metadata is not verbatim in the clone's solverforge.app.toml") unless contiguous?(normalized(read(File.join(clone, "solverforge.app.toml"))), meta)
  solver = normalized(toml_block(page, "Solver Policy"))
  fail!("page solver.toml differs from the clone's solver.toml") unless solver == normalized(read(File.join(clone, "solver.toml")))

  # Every Rust excerpt outside the scaffold path quotes the finished app.
  sources = Dir.glob(File.join(clone, "src/**/*.rs")).map { |path| File.read(path).lines.map(&:strip).reject(&:empty?) }
  scaffold = TutorialReplay.section(page, "Build the App from the Scaffold")
  excerpts = TutorialReplay.fenced_blocks(page.sub(scaffold, "")).select { |block| block.language == "rust" && TutorialReplay.file_path(block).nil? }
  excerpts.each do |block|
    lines = block.body.lines.map(&:strip).reject(&:empty?)
    fail!("Rust excerpt is not verbatim in the clone's src/:\n#{block.body}") unless sources.any? { |source| contiguous?(source, lines) }
  end
  log "#{excerpts.size} Rust excerpts are verbatim in the clone"

  routes_rs = read(File.join(clone, "src/api/routes.rs"))
  served = routes_rs.scan(/\.route\("([^"]+)",\s*([^\n]*)\)/).flat_map do |path, handlers|
    handlers.scan(/\b(get|post|put|delete|patch)\(/).flatten.map { |method| "#{method.upcase} #{path}" }
  end.to_set
  route_block = TutorialReplay.fenced_blocks(TutorialReplay.section(page, "Runtime and Browser Behavior")).find { |block| block.language == "text" } ||
                fail!("Runtime and Browser Behavior has no route list")
  listed = route_block.body.lines.map { |line| line.split.first(2).join(" ") }.reject(&:empty?).to_set
  fail!("page routes #{(listed - served).to_a} are not served by the clone") unless listed.subset?(served)
  fail!("clone serves job routes the page omits: #{(served - listed).to_a}") unless (served.select { |route| route.include?("/jobs") }.to_set - listed).empty?

  rows = table_rows(TutorialReplay.section(page, "Quick Reference"))
  rows.each do |need, where|
    where.to_s.scan(/`([^`]+)`/).flatten.each do |path|
      next if path.start_with?("solverforge-hospital@")

      fail!("Quick Reference row #{need.inspect} names #{path}, which the clone does not have") if Dir.glob(File.join(clone, path)).empty?
    end
  end
  tag = rows.find { |need, _| need.include?("Tagged app release") } || fail!("Quick Reference has no tagged release row")
  fail!("Quick Reference release tag must be solverforge-hospital@#{APP_VERSION}") unless tag[1].include?("solverforge-hospital@#{APP_VERSION}")
end

def check_dataset(page, app, demo_id)
  plan = app.get_json("/demo-data/#{demo_id}")
  problem = TutorialReplay.section(page, "The Problem We're Solving")
  employees = problem[/(\d+) employees/, 1]&.to_i || fail!("The Problem We're Solving states no employee count")
  shifts = problem[/(\d+) shifts/, 1]&.to_i || fail!("The Problem We're Solving states no shift count")
  actual = [plan.fetch("employees").size, plan.fetch("shifts").size]
  fail!("page states #{employees} employees and #{shifts} shifts; #{demo_id} has #{actual[0]} and #{actual[1]}") unless actual == [employees, shifts]
  log "#{demo_id} holds #{employees} employees and #{shifts} shifts, as the page states"
end

def analysis_ids(app, job_id)
  app.get_json("/jobs/#{job_id}/analysis").fetch("analysis").fetch("constraints").map { |constraint| constraint.fetch("name") }
end

# The first `data:` payload of the job's SSE stream.
def first_event(app, job_id)
  uri = URI("#{app.base_url}/jobs/#{job_id}/events")
  raw = +""
  Timeout.timeout(15) do
    Net::HTTP.start(uri.host, uri.port, read_timeout: 15) do |http|
      http.request(Net::HTTP::Get.new(uri)) do |response|
        fail!("GET /jobs/#{job_id}/events returned #{response.code}") unless response.is_a?(Net::HTTPSuccess)
        response.read_body do |chunk|
          raw << chunk
          events = raw.gsub("\r\n", "\n").split("\n\n", -1)[0...-1]
          data = events.map { |event| event.lines.grep(/\Adata:/).map { |line| line.sub(/\Adata:\s?/, "").chomp }.join("\n") }.find { |payload| !payload.empty? }
          return JSON.parse(data) if data
        end
      end
    end
  end
  fail!("SSE stream sent no data event")
rescue Timeout::Error, Net::ReadTimeout
  fail!("SSE stream sent no data event within 15s")
end

def check_live(page)
  cli_bin = TutorialReplay.install_cli(CLI_VERSION, log: method(:log))
  ids = rule_ids(page)

  TutorialReplay.with_workspace("hospital-scaffold", cli_bin: cli_bin, log: method(:log)) do |workspace|
    log "Scaffold path: replaying #{SCAFFOLD_SECTIONS.join(" + ")}"
    steps, run_command = split_run(page_steps(page, SCAFFOLD_SECTIONS), "scaffold")
    cargo_env = { "CARGO_TARGET_DIR" => TutorialReplay.target_dir(workspace, "hospital-scaffold") }
    workspace.replay(steps, skip: method(:skip_reason), env: cargo_env)
    toml = read(File.join(workspace.cwd, "solverforge.app.toml"))
    fail!("scaffold does not record cli_version #{CLI_VERSION}") unless toml.include?(%(cli_version = "#{CLI_VERSION}"))
    fail!("scaffold does not target solverforge #{RUNTIME_VERSION}") unless toml.include?(%(target = "solverforge #{RUNTIME_VERSION}"))

    workspace.run("cargo build --release", env: cargo_env)
    TutorialReplay.boot(workspace, run_command, env: cargo_env, log: method(:log)) do |app|
      result = app.solve(timeout: 120, require_terminal: true)
      claimed = TutorialReplay.section(page, "Build the App from the Scaffold")[/`(-?\d+)hard\//, 1] ||
                fail!("the scaffold path states no hard score for its solve")
      fail!("scaffold solve reached #{result[:score]}, the page states #{claimed}hard") unless result[:score].start_with?("#{claimed}hard/")
      names = analysis_ids(app, result[:job_id])
      fail!("scaffold analysis reports #{names}, the page table lists #{ids}") unless names.to_set == ids.to_set
      app.delete_job(result[:job_id])
      log "Scaffold path solved: #{result[:state]} #{result[:score]}"
    end
  end

  TutorialReplay.with_workspace("hospital-space", cli_bin: cli_bin, log: method(:log)) do |workspace|
    log "Finished example: replaying #{FINISHED_SECTIONS.join(" + ")}"
    steps, run_command = split_run(page_steps(page, FINISHED_SECTIONS), "finished-example")
    cargo_env = { "CARGO_TARGET_DIR" => TutorialReplay.target_dir(workspace, "hospital-space") }
    entered = steps.index { |step| step.shell? && step.text == "cd solverforge-hospital" } || fail!("no cd into the clone")
    workspace.replay(steps[0..entered], skip: method(:skip_reason))
    check_clone_facts(page, workspace.cwd)
    workspace.replay(steps[(entered + 1)..], skip: method(:skip_reason), env: cargo_env)
    TutorialReplay.boot(workspace, run_command, env: cargo_env, log: method(:log)) do |app|
      demo_ids = app.get_json("/demo-data")
      fail!("the page documents one dataset, LARGE; /demo-data returned #{demo_ids}") unless demo_ids == ["LARGE"]
      check_dataset(page, app, "LARGE")
      result = app.solve(demo_id: "LARGE", timeout: 120)
      event = first_event(app, result[:job_id])
      fail!("SSE bootstrap event lacks eventType/lifecycleState: #{event}") unless event["eventType"].is_a?(String) && event["lifecycleState"].is_a?(String)
      names = analysis_ids(app, result[:job_id])
      fail!("Space analysis reports #{names}, the page table lists #{ids}") unless names.to_set == ids.to_set
      app.delete_job(result[:job_id])
      log "Finished example solved: #{result[:state]} #{result[:score]}"
    end

    log "Finished example: replaying Making Your First Customization"
    custom = page_steps(page, ["Making Your First Customization"])
    added = custom.select(&:shell?).map(&:text).grep(/\Asolverforge generate constraint /).map { |command| command.split[3] }
    fail!("Making Your First Customization generates no constraint") if added.empty?
    workspace.replay(custom, skip: method(:skip_reason), env: cargo_env)
    workspace.run("cargo build --release", env: cargo_env)
    TutorialReplay.boot(workspace, run_command, env: cargo_env, log: method(:log)) do |app|
      result = app.solve(demo_id: "LARGE", timeout: 120)
      names = analysis_ids(app, result[:job_id])
      fail!("customized analysis reports #{names}, expected #{ids + added}") unless names.to_set == (ids + added).to_set
      app.delete_job(result[:job_id])
      log "Customized example solved: #{result[:state]} #{result[:score]}"
    end
  end
end

begin
  page = check_static
  if ARGV.include?("--static")
    log "Static hospital page contract passed"
  else
    check_live(page)
    log "Hospital page contract passed: both paths replayed, built, booted and solved"
  end
rescue TutorialReplay::Failure => e
  fail!(e.message)
end
