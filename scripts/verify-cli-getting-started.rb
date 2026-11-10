#!/usr/bin/env ruby
# frozen_string_literal: true

# Holds the CLI Getting Started page to what it teaches.
#
# The page is the source of truth: its bash blocks are run in page order from
# one working directory with the published CLI, every "complete
# `src/...rs`" listing is written over the generated file exactly as the
# reader copies it, and the run must end in a completed solve with no hard
# violations. Nothing here skips: a missing tool or a failed build is a
# failure, because a gate that can skip reports the same green as a pass.
#
#   ruby scripts/verify-cli-getting-started.rb            # static + live
#   ruby scripts/verify-cli-getting-started.rb --static   # page contract only
#
# The live run needs `solverforge` (or SOLVERFORGE_BIN) at the pinned version,
# cargo, and network access to crates.io.

require "fileutils"
require "json"
require "net/http"
require "open3"
require "rubygems/version"
require "shellwords"
require "socket"
require "tmpdir"
require "uri"
require_relative "release_pins"

SITE_ROOT = File.expand_path("..", __dir__)
PAGE = File.join(SITE_ROOT, "src/docs/solverforge-cli/getting-started.md")
APP_NAME = "my-scheduler"
DOCUMENTED_PORT = 7860
MIN_RUST = Gem::Version.new("1.95")
BOOT_TIMEOUT_SECONDS = 1200
SOLVE_TIMEOUT_SECONDS = 180
COMMAND_PREFIXES = %w[cargo cd curl rustc solverforge].freeze

def log(message)
  puts "[verify-cli-getting-started] #{message}"
end

def fail!(message)
  warn "[verify-cli-getting-started] ERROR: #{message}"
  exit 1
end

def page_text
  fail!("missing page: #{PAGE}") unless File.file?(PAGE)
  File.read(PAGE)
end

# Fenced blocks of one language, in page order.
def fenced_blocks(text, language)
  text.scan(/^ *```#{Regexp.escape(language)}\n(.*?)^ *```$/m).map(&:first)
end

def page_commands(text)
  fenced_blocks(text, "bash").flat_map do |block|
    block.lines.map(&:strip).reject { |line| line.empty? || line.start_with?("#") }
  end
end

# `The complete `src/x.rs`:` followed by a rust block: the file the reader writes.
def page_listings(text)
  text.scan(/complete\s+`(src\/[^`]+\.rs)`:\s*\n\s*```rust\n(.*?)^```$/m).to_h
end

def expected_version_output
  <<~TEXT
    solverforge solverforge-cli #{ReleasePins::CLI}
    CLI version: #{ReleasePins::CLI}
    Scaffold runtime target: SolverForge crate target #{ReleasePins::CLI_SCAFFOLD_RUNTIME}
    Scaffold UI target: solverforge-ui #{ReleasePins::UI}
    Scaffold maps target: solverforge-maps #{ReleasePins::MAPS}
  TEXT
end

def check_static(text)
  commands = page_commands(text)
  fail!("page has no bash commands") if commands.empty?
  commands.each do |command|
    word = command.split.first
    fail!("unexpected command on the page: #{command}") unless COMMAND_PREFIXES.include?(word)
    fail!("the page passes a field the CLI already writes: #{command}") if command.match?(/--field\s+['"]?(id|name):/)
  end
  fail!("page must install the published CLI") unless commands.include?("cargo install solverforge-cli --locked")
  fail!("page must scaffold #{APP_NAME}") unless commands.include?("solverforge new #{APP_NAME}")
  fail!("page must build the app with cargo build") unless commands.include?("cargo build")
  servers = commands.count("solverforge server")
  fail!("page must start the server before and after growing the model, found #{servers} starts") unless servers >= 2
  post = "curl -s -X POST -H 'content-type: application/json' --data @plan.json localhost:#{DOCUMENTED_PORT}/jobs"
  fail!("page must solve with #{post}") unless commands.count(post) >= 2

  log "Checking the version output against the release pins"
  version_block = fenced_blocks(text, "text").find { |block| block.start_with?("solverforge solverforge-cli ") }
  fail!("page shows no `solverforge --version` output") unless version_block
  fail!("version output on the page does not match the pins:\n#{version_block}") unless version_block.start_with?(expected_version_output)

  log "Checking that every generated constraint has a complete replacement"
  listings = page_listings(text)
  generated = commands.filter_map { |command| command[/\Asolverforge generate constraint (\S+)/, 1] }
  fail!("page generates no constraints") if generated.empty?
  generated.each do |name|
    path = "src/constraints/#{name}.rs"
    fail!("page generates #{name} but shows no complete #{path}") unless listings.key?(path)
  end
  listings.each do |path, source|
    fail!("#{path} on the page still contains a placeholder panic") if source.match?(/\b(panic|todo|unimplemented)!/)
  end
  fail!("page must say a placeholder solve fails") unless text.include?(%("lifecycleState":"FAILED"))
  fail!("page must say check does not compile") unless text.include?("it does not compile the project")
  log "#{commands.size} commands, #{listings.size} complete listings"
  [commands, listings]
end

def command?(name)
  ENV.fetch("PATH", "").split(File::PATH_SEPARATOR).any? { |dir| File.executable?(File.join(dir, name)) }
end

def cli_binary
  configured = ENV["SOLVERFORGE_BIN"]
  return configured if configured && File.executable?(configured)
  fail!("SOLVERFORGE_BIN is not executable: #{configured}") if configured && !configured.empty?
  return "solverforge" if command?("solverforge")

  fail!("solverforge-cli #{ReleasePins::CLI} is required: cargo install solverforge-cli --version #{ReleasePins::CLI} --locked, or set SOLVERFORGE_BIN")
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

def http_ok?(url)
  Net::HTTP.get_response(URI(url)).is_a?(Net::HTTPSuccess)
rescue SystemCallError, IOError, Net::ReadTimeout
  false
end

def get_json(url)
  response = Net::HTTP.get_response(URI(url))
  fail!("GET #{url} returned #{response.code}") unless response.is_a?(Net::HTTPSuccess)
  JSON.parse(response.body)
end

class Server
  attr_reader :port, :pid

  def initialize(cli, app, env, log_path)
    @port = free_port
    @log_path = log_path
    # The page documents that the server honours PORT; the gate relies on it.
    @pid = Process.spawn(env.merge("PORT" => @port.to_s), cli, "server", chdir: app, out: log_path, err: log_path, pgroup: true)
  end

  def base_url
    "http://127.0.0.1:#{@port}"
  end

  def wait_until_healthy
    BOOT_TIMEOUT_SECONDS.times do
      fail!("server exited before it became healthy:\n#{File.read(@log_path)}") if Process.waitpid(@pid, Process::WNOHANG)
      return if http_ok?("#{base_url}/health")

      sleep 1
    end
    fail!("server never answered /health:\n#{File.read(@log_path)}")
  end

  def log_text
    File.read(@log_path)
  end

  def stop
    # `solverforge server` runs the app through cargo; stop the whole group.
    Process.kill("TERM", -@pid)
    Process.wait(@pid)
  rescue Errno::ESRCH, Errno::ECHILD
    nil
  end
end

def parse_score(score)
  match = score.to_s.match(/\A(-?\d+)hard\/(-?\d+)soft\z/) || fail!("unparseable score #{score.inspect}")
  [match[1].to_i, match[2].to_i]
end

def wait_for_terminal(server, job_id)
  job = nil
  SOLVE_TIMEOUT_SECONDS.times do
    job = get_json("#{server.base_url}/jobs/#{job_id}")
    return job if %w[COMPLETED CANCELLED FAILED].include?(job["lifecycleState"])

    sleep 1
  end
  fail!("job #{job_id} never finished; last state #{job && job["lifecycleState"]}")
end

def run_curl(command, server, app)
  fail!("curl before a server is running: #{command}") unless server
  request, redirect = command.gsub("localhost:#{DOCUMENTED_PORT}", "127.0.0.1:#{server.port}").split(" > ", 2)
  argv = Shellwords.split(request)
  path = argv.last
  # The page reads the job before the 30-second solve ends; wait for it the way
  # the page tells the reader to, then read it.
  if path.match?(%r{/jobs/\d+\z})
    job = wait_for_terminal(server, path[%r{/jobs/(\d+)\z}, 1])
    unless job["lifecycleState"] == "COMPLETED"
      fail!("job ended #{job["lifecycleState"]}, not COMPLETED:\n#{server.log_text.lines.last(20).join}")
    end
    hard, soft = parse_score(job["bestScore"])
    fail!("bestScore #{job["bestScore"]} has hard violations") unless hard.zero?
    fail!("bestScore #{job["bestScore"]} has a positive soft part") if soft.positive?
    log "job #{job["id"]}: #{job["lifecycleState"]} #{job["bestScore"]}"
  end
  output = run!({}, argv, chdir: app)
  File.write(File.join(app, redirect.strip), output) if redirect
  if path.end_with?("/analysis")
    names = JSON.parse(output).fetch("analysis").fetch("constraints").map { |constraint| constraint.fetch("name") }
    log "analysis constraints: #{names.join(", ")}"
  end
  output
end

def check_live(commands, listings)
  fail!("cargo is required for the live getting-started check") unless command?("cargo")
  fail!("curl is required for the live getting-started check") unless command?("curl")
  cli = cli_binary

  root = Dir.mktmpdir("solverforge-cli-getting-started.")
  cwd = root
  app = File.join(root, APP_NAME)
  server = nil
  solved = 0
  env = {
    "CARGO_TARGET_DIR" => ENV.fetch("SOLVERFORGE_GETTING_STARTED_TARGET_DIR", File.join(root, "target")),
    "GIT_AUTHOR_NAME" => "getting-started", "GIT_AUTHOR_EMAIL" => "getting-started@localhost",
    "GIT_COMMITTER_NAME" => "getting-started", "GIT_COMMITTER_EMAIL" => "getting-started@localhost"
  }
  begin
    commands.each do |command|
      log "$ #{command}"
      argv = Shellwords.split(command)
      case argv.first
      when "cargo"
        if argv[1] == "install"
          version = run!({}, [cli, "--version"], chdir: root)
          fail!("installed CLI is not the published #{ReleasePins::CLI}:\n#{version}") unless version.start_with?(expected_version_output)
          next
        end
        run!(env, argv, chdir: cwd)
      when "rustc"
        version = run!({}, argv, chdir: cwd)[/rustc (\d+\.\d+)/, 1] || fail!("unreadable rustc version")
        fail!("rustc #{version} is older than #{MIN_RUST}") if Gem::Version.new(version) < MIN_RUST
      when "cd"
        cwd = File.expand_path(argv[1], cwd)
        fail!("cd into a missing directory: #{cwd}") unless Dir.exist?(cwd)
      when "curl"
        run_curl(command, server, cwd)
        solved += 1 if command.include?("-X POST")
      when "solverforge"
        argv[0] = cli
        if argv[1] == "server"
          server&.stop
          server = Server.new(cli, cwd, env, File.join(root, "server-#{solved}.log"))
          server.wait_until_healthy
          log "server healthy on port #{server.port}"
        elsif argv[1] == "--version"
          output = run!({}, argv, chdir: cwd)
          fail!("solverforge --version differs from the page") unless output.start_with?(expected_version_output)
        else
          output = run!(env, argv, chdir: cwd)
          if argv[1] == "generate" && argv[2] == "constraint"
            # The reader replaces the placeholder right after generating it.
            path = "src/constraints/#{argv[3]}.rs"
            fail!("generate constraint did not write #{path}") unless File.file?(File.join(app, path))
            File.write(File.join(app, path), listings.fetch(path))
          end
          fail!("solverforge check reported a problem:\n#{output}") if argv[1] == "check" && output.match?(/error|warning/i)
        end
      end
    end
    fail!("expected two solves, found #{solved}") unless solved >= 2
  ensure
    server&.stop
    FileUtils.remove_entry(root) if root && Dir.exist?(root)
  end
end

registry = ReleasePins.registry_failures
fail!(registry.join("\n")) unless registry.empty?
commands, listings = check_static(page_text)
if ARGV.include?("--static")
  log "Static getting-started contract passed"
else
  check_live(commands, listings)
  log "Getting Started contract passed: replayed with solverforge-cli #{ReleasePins::CLI}, built, and solved"
end
