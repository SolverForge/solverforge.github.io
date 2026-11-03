#!/usr/bin/env ruby
# frozen_string_literal: true

# Holds the SolverForge Python docs to what a reader gets from PyPI.
#
# The pages are the source of truth. The live run:
#
# - replays Getting Started in a fresh directory: its install block creates a
#   venv and installs the pinned package from PyPI, every block the page says
#   to save or add to a file is written, every command block runs, and each
#   command's stdout must equal the `text` block printed right after it;
# - checks the wheel table and the pin against the PyPI release;
# - imports every name in the API Surface table from the installed package;
# - parses every row of the Required Selector Fields table with the installed
#   solver: the listed fields must be enough, and dropping any one of them must
#   be rejected as a missing field;
# - runs every complete example (a python block containing `assert`) on the
#   Python pages, the `examples.*` ones inside the tagged source checkout;
# - replays the Hospital Example's published-package path: clone the tag,
#   install `solverforge[examples]`, boot the app on the URL the page names,
#   POST the demo data to `/jobs`, and require a COMPLETED job with a score;
# - checks the Hospital Example's constraint-kind list against the example's
#   constraint sources.
#
# Nothing here skips. The source-build blocks (`make develop`) compile the
# binding with Rust and are not replayed; the run checks that the tag they
# check out exists and defines the `make` targets they call.
#
#   ruby scripts/verify-python-docs.rb            # static + live
#   ruby scripts/verify-python-docs.rb --static   # page contract only
#
# Environment:
#   SOLVERFORGE_PY_GATE_PORT   port for the hospital app (default: the page's)
#   PIP_CACHE_DIR              honoured by pip; CI caches it

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
DOCS = File.join(SITE_ROOT, "src/docs/solverforge-python")
GETTING_STARTED = File.join(DOCS, "getting-started.md")
INDEX = File.join(DOCS, "index.md")
HOSPITAL = File.join(DOCS, "hospital-example.md")
RUNTIME = File.join(DOCS, "solving-and-runtime.md")
PYPI_URL = "https://pypi.org/pypi/solverforge/json"
SOLVE_TIMEOUT_SECONDS = 180
BOOT_TIMEOUT_SECONDS = 120

STREAM_METHOD_FOR_KIND = {
  "unary" => ".for_each(",
  "joined" => ".join(",
  "grouped" => ".group_by(",
  "balance" => ".balance(",
  "flattened" => ".flatten_last(",
  "existence" => ".if_exists("
}.freeze

def log(message)
  puts "[verify-python-docs] #{message}"
end

def fail!(message)
  warn "[verify-python-docs] ERROR: #{message}"
  exit 1
end

def rel(path)
  path.delete_prefix("#{SITE_ROOT}/")
end

def read(path)
  fail!("missing file: #{rel(path)}") unless File.file?(path)
  File.read(path)
end

# The body of a heading's section, up to the next heading of the same or a
# higher level. Fenced code is skipped so a quoted `#` line cannot end it.
def section(text, heading, page)
  level = heading[/\A#+/].size
  lines = text.lines
  start = lines.index("#{heading}\n") || fail!("#{rel(page)} has no section: #{heading}")
  body = []
  fenced = false
  lines[(start + 1)..].each do |line|
    fenced = !fenced if line.start_with?("```")
    if !fenced && (match = line[/\A(#+) /, 1]) && match.size <= level
      break
    end

    body << line
  end
  body.join
end

def without_section(text, heading, page)
  return text unless text.lines.include?("#{heading}\n")

  text.sub(section(text, heading, page), "")
end

# Fences in order, each with the paragraph line right above it and whether a
# `text` fence follows it directly.
def fences(text)
  out = []
  text.scan(/(?:^([^\n]*)\n\n)?^```([a-z]*)\n(.*?)^```$/m) do
    out << { intro: Regexp.last_match(1).to_s, language: Regexp.last_match(2), body: Regexp.last_match(3), offset: Regexp.last_match.begin(0) }
  end
  out.each_with_index do |fence, index|
    following = out[index + 1]
    between = following && text[fence[:offset]...following[:offset]]
    fence[:output] = following[:body] if following && following[:language] == "text" &&
                                         between.sub(/\A.*?^```$\n/m, "").strip.empty?
  end
  out
end

def blocks(text, language)
  text.scan(/^```#{language}\n(.*?)^```$/m).map(&:first)
end

def commands(body)
  body.lines.map(&:strip).reject { |line| line.empty? || line.start_with?("#") }
end

def pinned_version
  read(GETTING_STARTED)[/pip install "solverforge==([0-9][0-9.]*)"/, 1] || fail!("Getting Started does not pin solverforge==<version>")
end

def table_rows(text)
  text.lines.map(&:strip).select { |line| line.start_with?("|") }.drop(2).map do |line|
    line.split("|").map(&:strip).reject(&:empty?)
  end
end

def check_static
  pin = pinned_version
  log "Getting Started pins solverforge==#{pin}"

  Dir.glob(File.join(DOCS, "*.md")).sort.each do |page|
    text = read(page)
    text.scan(/solverforge(?:\[examples\])?==([0-9][0-9.]*)/).flatten.each do |version|
      fail!("#{rel(page)} pins solverforge==#{version}, Getting Started pins #{pin}") unless version == pin
    end
    text.scan(/git checkout v([0-9][0-9.]*)/).flatten.each do |version|
      fail!("#{rel(page)} checks out v#{version}, Getting Started pins #{pin}") unless version == pin
    end
  end

  install = fences(section(read(GETTING_STARTED), "## Install", GETTING_STARTED))
  first = install.first || fail!("Install has no command block")
  fail!("Install must start with a bash block") unless first[:language] == "bash"
  fail!("the Install block must print the installed version") unless commands(first[:body]).last.include?("solverforge.__version__")
  fail!("the Install block must be followed by its printed version") unless first[:output]&.strip == pin

  replay_plan(read(GETTING_STARTED))
  api_names
  selector_rows
  hospital_run_section
  log "static contract OK"
end

# Getting Started from Install to the end, minus the source-build subsection.
def replay_plan(page, strict: true)
  body = without_section(page[page.index("## Install\n")..], "### From The Tagged Source", GETTING_STARTED)
  plan = []
  fences(body).each do |fence|
    next if fence[:language] == "text"

    if fence[:language] == "bash"
      plan << { run: commands(fence[:body]), expect: fence[:output] }
    elsif (path = fence[:intro][/`([A-Za-z0-9_.\/-]+)`:\z/, 1])
      plan << { path: path, append: fence[:intro].match?(/\badd\b|\bappend\b/i), body: fence[:body] }
    elsif fence[:language] == "python"
      plan << { error: "Getting Started has a python block the reader is never told to save:\n#{fence[:body]}" }
    else
      plan << { shown: fence[:language] }
    end
  end
  plan.each { |step| fail!(step[:error]) if step[:error] } if strict
  runs = plan.count { |step| step[:run] }
  fail!("Getting Started replay has #{runs} command blocks; expected the install block and at least one run") if runs < 2
  plan
end

def api_names
  rows = table_rows(section(read(INDEX), "## API Surface", INDEX))
  fail!("API Surface table is empty") if rows.empty?
  rows.flat_map { |row| row[1].scan(/`([^`]+)`/).flatten }.map do |code|
    code.delete_prefix("@").sub(/\(.*\z/, "").delete_prefix("solverforge.")
  end.reject { |name| name.include?("=") || name.include?(" ") }.uniq
end

def selector_rows
  rows = table_rows(section(read(RUNTIME), "### Required Selector Fields", RUNTIME))
  fail!("Required Selector Fields table is empty") if rows.empty?
  rows.map do |row|
    type = row[0].delete("`")
    fields = row[1] == "none" ? [] : row[1].scan(/`([a-z_]+)`/).flatten
    { type: type, fields: fields }
  end
end

def hospital_run_section
  run = section(read(HOSPITAL), "## Run The Demo", HOSPITAL)
  clone = commands(blocks(run, "bash").first || fail!("Run The Demo has no clone block"))
  fail!("Run The Demo must start by cloning solverforge-py") unless clone.first&.start_with?("git clone https://github.com/SolverForge/solverforge-py.git")
  published = section(run, "### With The Published Package", HOSPITAL)
  steps = commands(blocks(published, "bash").first || fail!("With The Published Package has no command block"))
  server = steps.last
  fail!("the published-package block must end by starting the app") unless server.start_with?("python -m examples.solverforge_hospital")
  url = run[%r{`(http://127\.0\.0\.1:\d+)/?`}, 1] || fail!("Run The Demo does not name the URL the app serves")
  port = url[/:(\d+)\z/, 1]
  fail!("the app command does not serve #{url}") unless server.include?("--port #{port}") || port == "7860"
  { clone: clone, install: steps[0...-1], server: server, url: url, port: Integer(port) }
end

# --- live -------------------------------------------------------------------

def run!(command, cwd:, env: {})
  log "$ #{command}"
  stdout, stderr, status = Open3.capture3(env, "bash", "-c", "set -eo pipefail\n#{command}", chdir: cwd)
  fail!("command failed (exit #{status.exitstatus}) in #{cwd}: #{command}\n#{stdout}#{stderr}") unless status.success?
  stdout
end

def venv_env(venv)
  { "VIRTUAL_ENV" => venv, "PATH" => "#{venv}/bin:#{ENV.fetch('PATH')}", "PYTHONDONTWRITEBYTECODE" => "1" }
end

def http(method, url, body = nil)
  uri = URI(url)
  Net::HTTP.start(uri.host, uri.port, open_timeout: 2, read_timeout: 30) do |client|
    request = method == :post ? Net::HTTP::Post.new(uri, "content-type" => "application/json") : Net::HTTP::Get.new(uri)
    request.body = body if body
    client.request(request)
  end
end

def pypi_release
  JSON.parse(Net::HTTP.get(URI(PYPI_URL)))
rescue StandardError => e
  fail!("could not read #{PYPI_URL}: #{e.message}")
end

def check_pypi(pin)
  release = pypi_release
  latest = release.dig("info", "version")
  fail!("the docs pin solverforge==#{pin}, PyPI publishes #{latest}") unless latest == pin
  files = release.fetch("urls").map { |file| file["filename"] }
  wheels = files.select { |name| name.end_with?(".whl") }.map { |name| name.delete_suffix(".whl").split("-", 3).last }.to_set
  fail!("PyPI #{pin} has no source distribution") unless files.any? { |name| name.end_with?(".tar.gz") }
  documented = table_rows(section(read(GETTING_STARTED), "## Prerequisites", GETTING_STARTED)).map { |row| row[1].delete("`") }.to_set
  fail!("wheel table #{documented.to_a.sort} does not match PyPI #{pin} wheels #{wheels.to_a.sort}") unless documented.all? { |doc| wheels.any? { |tag| tag.start_with?(doc) } } &&
                                                                                                           wheels.all? { |tag| documented.any? { |doc| tag.start_with?(doc) } }
  log "PyPI solverforge #{latest}: #{wheels.size} wheels match the table, sdist present"
end

def replay_getting_started(workdir, pin)
  dir = File.join(workdir, "getting-started")
  FileUtils.mkdir_p(dir)
  env = {}
  replay_plan(read(GETTING_STARTED), strict: false).each_with_index do |step, index|
    if step[:error]
      fail!(step[:error])
    elsif step[:shown]
      log "shown, not run: #{step[:shown]} block"
    elsif step[:path]
      log "#{step[:append] ? 'appending to' : 'saving'} #{step[:path]}"
      File.open(File.join(dir, step[:path]), step[:append] ? "a" : "w") { |file| file.write(step[:body]) }
    else
      stdout = run!(step[:run].join("\n"), cwd: dir, env: env)
      env = venv_env(File.join(dir, ".venv")) if File.exist?(File.join(dir, ".venv/bin/activate"))
      if index.zero?
        # The install block promises the installed version; it must print it.
        printed = stdout.lines.map(&:strip).reject(&:empty?).last.to_s
        fail!("the install block does not print the installed version #{pin}; its last line is #{printed.inspect}") unless printed == pin
        log "install block printed #{printed}"
      end
      next unless step[:expect]

      actual = stdout.lines.map(&:rstrip).reject(&:empty?)
      expected = step[:expect].lines.map(&:rstrip).reject(&:empty?)
      if step[:run].any? { |command| command.include?("pip install") }
        actual = actual.last(expected.size)
      end
      fail!("output of `#{step[:run].last}` differs from the page:\npage:\n#{expected.join("\n")}\nactual:\n#{actual.join("\n")}") unless actual == expected
      log "output matches the page (#{expected.size} lines)"
    end
  end
  installed = run!("python -c 'import solverforge; print(solverforge.__version__)'", cwd: dir, env: env).strip
  fail!("Getting Started installed #{installed}, expected #{pin}") unless installed == pin
  env
end

def check_api_names(env, cwd)
  names = api_names
  script = <<~PY
    import importlib, json, sys
    missing = []
    for name in json.loads(sys.argv[1]):
        target = importlib.import_module("solverforge")
        try:
            for part in name.split("."):
                target = getattr(target, part)
        except AttributeError:
            missing.append(name)
    print(json.dumps(missing))
  PY
  missing = JSON.parse(run!("python -c #{Shellwords.escape(script)} #{Shellwords.escape(JSON.generate(names))}", cwd: cwd, env: env))
  fail!("API Surface names that solverforge does not export: #{missing.join(', ')}") unless missing.empty?
  log "#{names.size} API Surface names import from solverforge"
end

FIELD_VALUES = {
  "max_nearby" => 2, "minimum_sub_pillar_size" => 1, "maximum_sub_pillar_size" => 2,
  "min_ruin_count" => 1, "max_ruin_count" => 2, "recreate_heuristic_type" => "first_fit",
  "group_name" => "missing_group", "constraints" => ["missing constraint"],
  "min_sublist_size" => 1, "max_sublist_size" => 2, "min_window_size" => 2, "max_window_size" => 3,
  "k" => 2, "min_segment_len" => 1, "selected_count_limit" => 1,
  "selector" => { "type" => "change_move_selector" },
  "selectors" => [{ "type" => "change_move_selector" }, { "type" => "swap_move_selector" }]
}.freeze

def check_selector_fields(env, cwd)
  rows = selector_rows
  cases = rows.flat_map do |row|
    unknown = row[:fields] - FIELD_VALUES.keys
    fail!("no probe value for selector field(s) #{unknown.join(', ')}; add them to FIELD_VALUES") unless unknown.empty?
    full = { "type" => row[:type] }.merge(row[:fields].to_h { |field| [field, FIELD_VALUES.fetch(field)] })
    [{ type: row[:type], drop: nil, selector: full }] +
      row[:fields].map { |field| { type: row[:type], drop: field, selector: full.except(field) } }
  end
  script = <<~PY
    import json, sys
    from solverforge import HardSoftScore, Solver, constraint_provider, planning_entity, planning_solution, planning_variable

    @planning_entity
    class Shift:
        nurse = planning_variable(value_range_provider="nurses", allows_unassigned=True)
        def __init__(self, nurse=None):
            self.nurse = nurse

    @constraint_provider
    def constraints(factory):
        return [factory.for_each(Shift).filter(lambda s: s.nurse is None).penalize(HardSoftScore.ONE_HARD).named("unassigned")]

    @planning_solution(score=HardSoftScore, constraints=constraints)
    class Schedule:
        shifts: list[Shift]
        def __init__(self):
            self.shifts = [Shift(), Shift()]
            self.nurses = [0, 1]
            self.score = None

    results = []
    for case in json.loads(sys.stdin.read()):
        config = {"phases": [{"type": "local_search", "termination": {"step_count_limit": 1}, "move_selector": case["selector"]}]}
        try:
            Solver.solve(Schedule(), config=config)
            results.append("")
        except Exception as error:
            results.append(str(error))
    print(json.dumps(results))
  PY
  path = File.join(cwd, "selector_probe.py")
  File.write(path, script)
  stdout, stderr, status = Open3.capture3(env, "python", path, stdin_data: JSON.generate(cases), chdir: cwd)
  fail!("selector probe crashed:\n#{stderr}") unless status.success?
  JSON.parse(stdout).zip(cases).each do |error, test|
    missing = error[/missing field `([a-z_]+)`/, 1]
    if test[:drop].nil?
      fail!("#{test[:type]} with the documented fields is still rejected: #{error}") if missing || error.include?("unknown variant")
    elsif missing != test[:drop]
      fail!("#{test[:type]} without `#{test[:drop]}` was not rejected as missing that field (#{error.empty? ? 'accepted' : error})")
    end
  end
  log "#{rows.size} selector rows: documented fields parse, each one is required"
end

def complete_examples
  Dir.glob(File.join(DOCS, "*.md")).sort.flat_map do |page|
    blocks(read(page), "python").select { |code| code.match?(/^assert /) }.map { |code| { page: page, code: code } }
  end
end

def run_examples(examples, env, cwd, label)
  examples.each_with_index do |example, index|
    path = File.join(cwd, "docs_example_#{label}_#{index}.py")
    File.write(path, example[:code])
    stdout, stderr, status = Open3.capture3(env, "python", path, chdir: cwd)
    fail!("complete example from #{rel(example[:page])} failed:\n#{example[:code]}\n#{stdout}#{stderr}") unless status.success?
    log "complete example from #{rel(example[:page])} passes"
  end
end

def wait_for(url, pid)
  deadline = Time.now + BOOT_TIMEOUT_SECONDS
  loop do
    fail!("hospital app exited before serving #{url}") if Process.waitpid(pid, Process::WNOHANG)
    begin
      return http(:get, url)
    rescue SystemCallError, Net::OpenTimeout, Net::ReadTimeout, EOFError
      fail!("hospital app did not answer #{url} within #{BOOT_TIMEOUT_SECONDS}s") if Time.now > deadline
      sleep 1
    end
  end
end

def replay_hospital(workdir, pin)
  plan = hospital_run_section
  dir = File.join(workdir, "hospital")
  FileUtils.mkdir_p(dir)
  cwd = dir
  run!(plan[:clone].join("\n"), cwd: dir)
  plan[:clone].each { |command| cwd = File.expand_path(command.delete_prefix("cd ").strip, cwd) if command.start_with?("cd ") }
  checkout = cwd
  makefile = read(File.join(checkout, "Makefile"))
  %w[develop hospital-run hospital-solve].each do |target|
    fail!("solverforge-py v#{pin} has no `make #{target}` target") unless makefile.match?(/^#{Regexp.escape(target)}:/)
  end
  run!(plan[:install].join("\n"), cwd: checkout)
  env = venv_env(File.join(checkout, plan[:install].first[/-m venv (\S+)/, 1] || fail!("the published-package block does not create a venv")))

  constraint_sources = Dir.glob(File.join(checkout, "examples/solverforge_hospital/src/constraints/*.py")).map { |path| File.read(path) }.join
  kinds_line = read(HOSPITAL)[/^- ((?:[A-Z][a-z]+)(?:, [a-z]+)*,? and [a-z]+) constraints$/, 1] || fail!("Hospital Example does not list its constraint kinds")
  kinds_line.downcase.split(/,\s*(?:and\s+)?|\s+and\s+/).map(&:strip).reject(&:empty?).each do |kind|
    method = STREAM_METHOD_FOR_KIND[kind] || fail!("unknown constraint kind on the Hospital page: #{kind}")
    fail!("Hospital Example claims #{kind} constraints, but its constraints never call #{method}") unless constraint_sources.include?(method)
  end
  log "Hospital constraint kinds (#{kinds_line}) match the example source"

  run_examples(complete_examples.select { |example| example[:code].include?("from examples.") }, env, checkout, "hospital")

  port = Integer(ENV.fetch("SOLVERFORGE_PY_GATE_PORT", plan[:port].to_s))
  server = plan[:server]
  server = "#{server.sub(/ --port \d+/, '')} --port #{port}" if port != plan[:port]
  log "$ #{server}"
  pid = Process.spawn(env, "bash", "-c", server, chdir: checkout, pgroup: true,
                      out: File.join(workdir, "hospital.log"), err: [:child, :out])
  begin
    base = "http://127.0.0.1:#{port}"
    index = wait_for("#{base}/", pid)
    fail!("GET / returned #{index.code} #{index['content-type']}") unless index.code == "200" && index["content-type"].to_s.start_with?("text/html")
    health = JSON.parse(http(:get, "#{base}/health").body)
    fail!("/health is #{health}") unless health["status"] == "UP"
    data = http(:get, "#{base}/demo-data/LARGE")
    fail!("/demo-data/LARGE returned #{data.code}") unless data.code == "200"
    created = JSON.parse(http(:post, "#{base}/jobs", data.body).body)
    job = created["id"] || fail!("POST /jobs returned no id: #{created}")
    deadline = Time.now + SOLVE_TIMEOUT_SECONDS
    status = nil
    loop do
      status = JSON.parse(http(:get, "#{base}/jobs/#{job}/status").body)
      break unless %w[SOLVING PAUSE_REQUESTED].include?(status["lifecycleState"])
      fail!("job #{job} still #{status['lifecycleState']} after #{SOLVE_TIMEOUT_SECONDS}s") if Time.now > deadline

      sleep 2
    end
    fail!("hospital job ended #{status['lifecycleState']}: #{status}") unless status["lifecycleState"] == "COMPLETED"
    fail!("hospital job has no best score: #{status}") if status["bestScore"].to_s.empty?
    log "hospital job #{job}: COMPLETED with #{status['bestScore']}"
  ensure
    begin
      Process.kill("TERM", -pid)
      Process.wait(pid)
    rescue Errno::ESRCH, Errno::ECHILD
      nil
    end
  end
end

static_only = ARGV.include?("--static")
if static_only
  check_static
  exit 0
end

_out, found = Open3.capture2e("bash", "-c", "command -v python3.14 && command -v git")
fail!("python3.14 and git are required on PATH") unless found.success?
pin = pinned_version
workdir = Dir.mktmpdir("verify-python-docs-")
begin
  env = replay_getting_started(workdir, pin)
  check_pypi(pin)
  check_static
  gs_dir = File.join(workdir, "getting-started")
  check_api_names(env, gs_dir)
  check_selector_fields(env, gs_dir)
  run_examples(complete_examples.reject { |example| example[:code].include?("from examples.") }, env, gs_dir, "standalone")
  replay_hospital(workdir, pin)
  log "OK: the Python pages run as written against PyPI solverforge #{pin}"
ensure
  FileUtils.rm_rf(workdir) unless ENV["KEEP_PY_GATE_WORKDIR"]
end
