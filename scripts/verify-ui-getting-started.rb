#!/usr/bin/env ruby
# frozen_string_literal: true

# Builds the solverforge-ui Getting Started app exactly as the page writes it
# and loads it in a browser.
#
# The page is the source of truth: its command block creates the crate against
# the published crates.io packages, the blocks it tells the reader to save are
# written verbatim, and its run command boots the app. The gate then asserts
# what a reader sees: `/` is served as text/html, the header the page's script
# builds renders, `SF.version` equals the solverforge-ui version Cargo resolved,
# and the browser reports zero console errors. The Gantt and map snippets from
# Scheduling Views and Integration & Assets run against the same app's `/sf/*`
# assets. The retained-job route table and the createTable unsafe-HTML field
# are compared with the published crate's own `sf.js`.
#
# Nothing here skips: a missing tool, a failed build, or a page without the
# expected blocks is a failure.
#
#   ruby scripts/verify-ui-getting-started.rb
#
# Environment:
#   SOLVERFORGE_UI_GATE_TARGET_DIR  cargo target dir to reuse (CI caches it)
#   SOLVERFORGE_UI_GATE_PORT        port for the app (default: a free port)

require "fileutils"
require "json"
require "net/http"
require "open3"
require "set"
require "socket"
require "tmpdir"
require "uri"

SITE_ROOT = File.expand_path("..", __dir__)
DOCS = File.join(SITE_ROOT, "src/docs/solverforge-ui")
GETTING_STARTED = File.join(DOCS, "getting-started.md")
SCHEDULING_VIEWS = File.join(DOCS, "scheduling-views.md")
INTEGRATION = File.join(DOCS, "integration-assets.md")
COMPONENTS = File.join(DOCS, "components.md")
CHECKER = File.join(SITE_ROOT, "scripts/check-ui-app.mjs")
ALLOWED_COMMANDS = %w[cargo cd mkdir].freeze
BOOT_TIMEOUT_SECONDS = 600

def log(message)
  puts "[verify-ui-getting-started] #{message}"
end

def fail!(message)
  warn "[verify-ui-getting-started] ERROR: #{message}"
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

def fenced_blocks(text, language)
  text.scan(/^```#{Regexp.escape(language)}\n(.*?)^```$/m).map(&:first)
end

def one_block(text, language, where)
  blocks = fenced_blocks(text, language)
  fail!("#{where} must have exactly one #{language} block, found #{blocks.size}") unless blocks.size == 1
  blocks.first
end

def optional_block(text, language, where)
  blocks = fenced_blocks(text, language)
  fail!("#{where} has #{blocks.size} #{language} blocks; expected at most one") if blocks.size > 1
  blocks.first.to_s
end

def run_browser(origin, version, pages, workdir, name)
  spec_path = File.join(workdir, "#{name}.json")
  File.write(spec_path, JSON.pretty_generate({ origin: origin, version: version, pages: pages }))
  system("node", CHECKER, spec_path, chdir: SITE_ROOT) || fail!("browser check failed: #{name}")
end

def commands(block)
  block.lines.map(&:strip).reject { |line| line.empty? || line.start_with?("#") }
end

# Blocks the reader is told to save: a paragraph ending in "`path`:" directly
# above a fence. Returns { path => content } in page order.
def files_to_save(text)
  text.scan(/`([A-Za-z0-9_.\/-]+)`:\n\n```[a-z]+\n(.*?)^```$/m).to_h
end

def run!(command, cwd:, env: {})
  log "$ #{command}"
  stdout, stderr, status = Open3.capture3(env, "bash", "-c", command, chdir: cwd)
  return stdout if status.success?

  fail!("command failed (exit #{status.exitstatus}): #{command}\n#{stdout}#{stderr}")
end

def free_port
  server = TCPServer.new("127.0.0.1", 0)
  server.addr[1]
ensure
  server&.close
end

def http_get(url)
  uri = URI(url)
  Net::HTTP.start(uri.host, uri.port, open_timeout: 2, read_timeout: 10) { |http| http.get(uri.request_uri) }
end

def wait_for_http(url, pid)
  deadline = Time.now + BOOT_TIMEOUT_SECONDS
  loop do
    fail!("app process exited before serving #{url}") if Process.waitpid(pid, Process::WNOHANG)
    begin
      return http_get(url)
    rescue SystemCallError, Net::OpenTimeout, Net::ReadTimeout, EOFError
      fail!("app did not answer #{url} within #{BOOT_TIMEOUT_SECONDS}s") if Time.now > deadline
      sleep 1
    end
  end
end

# The routes the shipped HTTP adapter calls, read from the crate's sf.js.
def adapter_routes(sf_js)
  routes = Set.new
  sf_js.scan(/request\('([A-Z]+)', (?:withSnapshotRevision\()?(jobsPath|demoDataPath)((?: \+ '\/' \+ (?:id|\(name \|\| 'STANDARD'\))(?: \+ '\/[a-z]+')?)?)/) do |method, base, tail|
    path = base == "jobsPath" ? "/jobs" : "/demo-data"
    path += "/{id}" if tail.include?("id")
    path += "/{name}" if tail.include?("name")
    path += "/#{Regexp.last_match(1)}" if tail =~ %r{'/([a-z]+)'\z}
    routes << "#{method} #{path}"
  end
  routes << "GET /jobs/{id}/events" if sf_js.include?("jobsPath + '/' + id + '/events'")
  routes
end

def page_routes(text)
  table = section(text, "### Retained-Job HTTP Routes", INTEGRATION)
  rows = table.lines.map(&:strip).select { |line| line.start_with?("|") }.drop(2)
  fail!("Retained-Job HTTP Routes has no route rows") if rows.empty?
  rows.map do |row|
    cells = row.split("|").map(&:strip).reject(&:empty?)
    "#{cells[0].delete('`')} #{cells[1].delete('`')}"
  end
end

def check_source_contracts(source_dir)
  sf_js = read(File.join(source_dir, "static/sf/sf.js"))

  log "Comparing the retained-job route table with the published sf.js"
  expected = adapter_routes(sf_js)
  fail!("found no adapter routes in the published sf.js; the parser no longer matches it") if expected.size < 10
  listed = page_routes(read(INTEGRATION))
  fail!("route table lists duplicates: #{listed}") unless listed.uniq.size == listed.size
  unless listed.to_set == expected
    fail!("route table #{listed.sort} does not match the HTTP adapter #{expected.to_a.sort}")
  end
  log "#{listed.size} routes match the HTTP adapter"

  log "Comparing the createTable unsafe-HTML field with the published sf.js"
  table_body = sf_js[/sf\.createTable = function.*?\n  \};/m] || fail!("createTable not found in sf.js")
  field = if table_body.include?("config.rows.forEach") && table_body.include?("cell.unsafeHtml")
            "rows[][].unsafeHtml"
          else
            fail!("createTable no longer reads cell.unsafeHtml from config.rows; update the gate and the page")
          end
  row = read(COMPONENTS).lines.find { |line| line.start_with?("| `SF.createTable(config)`") && line.include?("unsafeHtml") }
  fail!("components.md has no createTable row in the unsafe-HTML table") unless row
  fail!("components.md names the createTable unsafe field wrongly: #{row.strip} (sf.js reads `#{field}`)") unless row.include?("`#{field}`")
end

def compose(html_block, js_block)
  <<~HTML
    <!doctype html>
    <html lang="en">
      <head><meta charset="utf-8" /><title>snippet</title></head>
      <body class="sf-app">
    #{html_block}
        <script>
    #{js_block}
        </script>
      </body>
    </html>
  HTML
end

page = read(GETTING_STARTED)
create = section(page, "## Create the Project", GETTING_STARTED)
create_commands = commands(one_block(create, "bash", "Create the Project"))
create_commands.each do |command|
  fail!("unexpected command in Create the Project: #{command}") unless ALLOWED_COMMANDS.include?(command.split.first)
end
ui_pin = create_commands.join("\n")[/solverforge-ui@([0-9][0-9.]*)/, 1] || fail!("Create the Project does not pin solverforge-ui@<version>")
files = files_to_save(page)
%w[src/main.rs static/index.html].each { |path| fail!("page never tells the reader to save #{path}") unless files.key?(path) }
run_commands = commands(one_block(section(page, "## Run the App", GETTING_STARTED), "bash", "Run the App"))
fail!("Run the App must give one command, found #{run_commands}") unless run_commands.size == 1
fail!("Run the App does not name the URL the app serves") unless page.include?("http://127.0.0.1:3000/")

%w[cargo node].each do |tool|
  _out, status = Open3.capture2e("bash", "-c", "command -v #{tool}")
  fail!("#{tool} is required") unless status.success?
end

workdir = Dir.mktmpdir("verify-ui-getting-started-")
target_dir = ENV.fetch("SOLVERFORGE_UI_GATE_TARGET_DIR", File.join(workdir, "target"))
env = { "CARGO_TARGET_DIR" => target_dir }
app_pid = nil

begin
  cwd = workdir
  create_commands.each do |command|
    if command.start_with?("cd ")
      cwd = File.expand_path(command.delete_prefix("cd ").strip, cwd)
      fail!("cd target does not exist: #{cwd}") unless Dir.exist?(cwd)
      log "$ #{command}"
      next
    end
    run!(command, cwd: cwd, env: env)
  end
  files.each do |path, content|
    log "saving #{path} from the page"
    full = File.join(cwd, path)
    FileUtils.mkdir_p(File.dirname(full))
    File.write(full, content)
  end

  run!("cargo build", cwd: cwd, env: env)
  metadata = JSON.parse(run!("cargo metadata --format-version 1 --locked", cwd: cwd, env: env))
  ui = metadata.fetch("packages").find { |package| package["name"] == "solverforge-ui" } || fail!("solverforge-ui not in the dependency graph")
  fail!("solverforge-ui comes from #{ui['source']}, not crates.io") unless ui["source"].to_s.include?("crates.io-index")
  fail!("Cargo resolved solverforge-ui #{ui['version']}, page pins #{ui_pin}") unless ui["version"] == ui_pin
  log "solverforge-ui #{ui['version']} from crates.io"

  port = Integer(ENV.fetch("SOLVERFORGE_UI_GATE_PORT", free_port.to_s))
  log "$ #{run_commands.first}   (PORT=#{port})"
  app_pid = Process.spawn(env.merge("PORT" => port.to_s), "bash", "-c", run_commands.first,
                          chdir: cwd, pgroup: true, out: File.join(workdir, "app.log"), err: [:child, :out])
  origin = "http://127.0.0.1:#{port}"
  response = wait_for_http("#{origin}/", app_pid)
  fail!("GET / returned #{response.code}") unless response.code == "200"
  content_type = response["content-type"].to_s
  log "GET / -> 200 #{content_type}"
  # The browser check asserts the content type, the rendered header, and
  # SF.version together, so a text/plain page reports every symptom a reader
  # sees rather than only the first.

  run_browser(origin, ui_pin, [{ name: "getting-started app", path: "/", expect: "app" }], workdir, "app")

  check_source_contracts(File.dirname(ui.fetch("manifest_path")))

  # The snippet pages are composed only from the docs blocks: an include block
  # (when the section has one) and the script block.
  gantt_section = section(read(SCHEDULING_VIEWS), "### Gantt Example", SCHEDULING_VIEWS)
  gantt_html = compose(optional_block(gantt_section, "html", "Gantt Example"), one_block(gantt_section, "js", "Gantt Example"))
  map_html = optional_block(section(read(INTEGRATION), "## Optional Modules", INTEGRATION), "html", "Optional Modules")
  map_js = one_block(section(read(INTEGRATION), "### Map Helper Surface", INTEGRATION), "js", "Map Helper Surface")
  run_browser(origin, ui_pin, [
    { name: "Scheduling Views: Gantt Example", path: "/__gate/gantt", expect: "gantt", html: gantt_html },
    { name: "Integration & Assets: map module", path: "/__gate/map", expect: "map", html: compose(map_html, map_js) }
  ], workdir, "snippets")
  log "OK: the page builds, serves text/html, reports SF.version #{ui_pin}, and loads with zero console errors"
ensure
  if app_pid
    begin
      Process.kill("TERM", -app_pid)
      Process.wait(app_pid)
    rescue Errno::ESRCH, Errno::ECHILD
      nil
    end
  end
  FileUtils.rm_rf(workdir) unless ENV["KEEP_UI_GATE_WORKDIR"]
end
