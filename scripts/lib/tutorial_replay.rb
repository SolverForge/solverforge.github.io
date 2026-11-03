# frozen_string_literal: true

# Replays a docs page the way a reader follows it.
#
# A tutorial gate built on this harness reads everything it runs from the page
# source: the fenced shell blocks of a section (in page order, `\` line
# continuations joined, `cd` honoured) and the complete files the page shows.
# It installs the published CLI at a pinned version into a cached root, runs
# the commands from one working directory, builds, boots the app with the
# page's own run command, solves the default demo data over HTTP and asserts
# the job did not fail. Nothing here skips: a missing tool is a failure.
#
# File convention. A fenced block is a complete file when its first line names
# the path, as a comment in that language:
#
#   ```rust
#   // file: src/domain/care_hub.rs
#   ...
#   ```
#
#   ```toml
#   # file: solver.toml
#   ...
#   ```
#
# The marker line stays in the written file (it is a valid comment), so the
# reader can paste the whole block. Blocks without the marker are excerpts and
# are never written.
#
# Environment:
#   SOLVERFORGE_CLI_CACHE     root for cached CLI installs (default ~/.cache/solverforge-cli)
#   TUTORIAL_REPLAY_TARGET_DIR  base for CARGO_TARGET_DIR per replay (default: inside the work dir)
#   TUTORIAL_REPLAY_KEEP=1    keep the work dir after a run

require "fileutils"
require "json"
require "net/http"
require "open3"
require "shellwords"
require "socket"
require "timeout"
require "tmpdir"
require "uri"

module TutorialReplay
  class Failure < StandardError; end

  SHELL_LANGUAGES = %w[bash sh shell console].freeze
  FILE_MARKER = %r{\A\s*(?://|#)\s*file:\s*(\S+)\s*\z}
  TERMINAL_STATES = %w[COMPLETED CANCELLED FAILED].freeze

  Step = Struct.new(:kind, :text, :path, :language, :line, keyword_init: true) do
    def shell? = kind == :shell
    def file? = kind == :file
  end

  Block = Struct.new(:language, :body, :line, keyword_init: true)

  module_function

  def fail!(message)
    raise Failure, message
  end

  # ---------------------------------------------------------------- page parsing

  # Every fenced block in page order, with its info-string language and the
  # 1-based line of its opening fence within `text`.
  def fenced_blocks(text)
    blocks = []
    current = nil
    text.lines.each_with_index do |line, index|
      if current
        if line.match?(/\A#{Regexp.escape(current[:fence])}\s*\z/)
          blocks << Block.new(language: current[:language], body: current[:body].join, line: current[:line])
          current = nil
        else
          current[:body] << line
        end
      elsif (match = line.match(/\A(```+|~~~+)\s*([\w+-]*)/))
        current = { fence: match[1], language: match[2].to_s.downcase, body: [], line: index + 1 }
      end
    end
    fail!("unterminated fenced block opened at line #{current[:line]}") if current
    blocks
  end

  # The body of the section opened by a heading whose text is `heading`
  # (any level), up to the next heading of the same or a higher level.
  # Headings inside fenced code are ignored.
  def section(text, heading)
    lines = text.lines
    fenced = false
    start = nil
    level = nil
    body = []
    lines.each do |line|
      fenced = !fenced if line.start_with?("```", "~~~")
      heading_match = !fenced && line.match(/\A(#+)\s+(.*?)\s*#*\s*\z/)
      if start
        break if heading_match && heading_match[1].size <= level

        body << line
      elsif heading_match && heading_match[2] == heading
        start = true
        level = heading_match[1].size
      end
    end
    fail!("page has no section headed #{heading.inspect}") unless start
    body.join
  end

  # Shell commands of one block: comments and blank lines dropped, `\`
  # continuations joined, `$ ` prompts stripped.
  def shell_commands(block_body)
    commands = []
    pending = +""
    block_body.each_line do |raw|
      line = raw.chomp
      if pending.empty?
        stripped = line.strip
        next if stripped.empty? || stripped.start_with?("#")

        line = stripped.delete_prefix("$ ")
      end
      if line.end_with?("\\")
        pending << line.chomp("\\").rstrip << " "
      else
        pending << line.strip
        commands << pending.squeeze(" ").strip
        pending = +""
      end
    end
    fail!("shell block ends in a line continuation: #{pending}") unless pending.empty?
    commands
  end

  # The path a block declares on its first line, or nil for an excerpt.
  def file_path(block)
    first = block.body.lines.first.to_s.chomp
    first[FILE_MARKER, 1]
  end

  # Ordered replay steps for a section: shell commands and complete files.
  def steps(section_text)
    fenced_blocks(section_text).flat_map do |block|
      if SHELL_LANGUAGES.include?(block.language)
        shell_commands(block.body).map { |command| Step.new(kind: :shell, text: command, language: block.language, line: block.line) }
      elsif (path = file_path(block))
        [Step.new(kind: :file, text: block.body, path: path, language: block.language, line: block.line)]
      else
        []
      end
    end
  end

  # Every complete file the page shows, keyed by path (later blocks win, as
  # they would for a reader pasting in order).
  def page_files(text)
    fenced_blocks(text).each_with_object({}) do |block, files|
      path = file_path(block)
      files[path] = block.body if path
    end
  end

  # ----------------------------------------------------------------- toolchain

  def command?(name)
    ENV.fetch("PATH", "").split(File::PATH_SEPARATOR).any? { |dir| File.executable?(File.join(dir, name)) }
  end

  def cli_cache_root
    ENV.fetch("SOLVERFORGE_CLI_CACHE", File.join(Dir.home, ".cache", "solverforge-cli"))
  end

  # Installs the published solverforge-cli at `version` into a cached root
  # and returns its bin directory. Reuses the cache when the binary already
  # reports that version.
  def install_cli(version, log: method(:puts))
    fail!("cargo is required to install solverforge-cli #{version}") unless command?("cargo")

    root = File.join(cli_cache_root, version)
    bin = File.join(root, "bin")
    binary = File.join(bin, "solverforge")
    if File.executable?(binary) && cli_version(binary) == version
      log.call("Using cached solverforge-cli #{version} at #{binary}")
      return bin
    end

    log.call("Installing solverforge-cli #{version} into #{root}")
    FileUtils.mkdir_p(root)
    output, status = Open3.capture2e("cargo", "install", "solverforge-cli", "--version", version, "--locked", "--force", "--root", root)
    fail!("cargo install solverforge-cli #{version} failed:\n#{output}") unless status.success?
    actual = cli_version(binary)
    fail!("installed solverforge reports #{actual.inspect}, expected #{version}") unless actual == version
    bin
  end

  def cli_version(binary)
    output, status = Open3.capture2e(binary, "--version")
    return nil unless status.success?

    output[/CLI version:\s*(\S+)/, 1] || output[/solverforge(?:-cli)?\s+(\d+\.\d+\.\d+\S*)/, 1]
  end

  def free_port
    server = TCPServer.new("127.0.0.1", 0)
    server.addr[1]
  ensure
    server&.close
  end

  # ------------------------------------------------------------------ workspace

  # One reader's terminal: a working directory that `cd` moves, and an
  # environment with the pinned CLI first on PATH.
  class Workspace
    attr_reader :root, :cwd, :env, :transcript

    def initialize(root:, cli_bin: nil, env: {}, log: method(:puts))
      @root = root
      @cwd = root
      @log = log
      @transcript = []
      path = [cli_bin, ENV.fetch("PATH", "")].compact.join(File::PATH_SEPARATOR)
      @env = {
        "PATH" => path,
        "CARGO_BUILD_JOBS" => ENV.fetch("CARGO_BUILD_JOBS", "3"),
        "GIT_TERMINAL_PROMPT" => "0",
        "GIT_AUTHOR_NAME" => "tutorial-replay", "GIT_AUTHOR_EMAIL" => "tutorial-replay@localhost",
        "GIT_COMMITTER_NAME" => "tutorial-replay", "GIT_COMMITTER_EMAIL" => "tutorial-replay@localhost"
      }.merge(env)
    end

    # Runs one page command from the current directory. `cd <dir>` moves the
    # workspace. Returns the combined output; raises on a non-zero exit.
    def run(command, env: {}, allow_failure: false)
      if (match = command.match(/\Acd\s+(\S+)\z/))
        target = File.expand_path(match[1], @cwd)
        TutorialReplay.fail!("`#{command}`: no such directory #{target}") unless Dir.exist?(target)
        @log.call("$ #{command}")
        @transcript << { command: command, cwd: @cwd, exit: 0 }
        @cwd = target
        return ""
      end

      @log.call("$ #{command}    (in #{relative(@cwd)})")
      output, status = Open3.capture2e(@env.merge(env), "bash", "-c", command, chdir: @cwd)
      @transcript << { command: command, cwd: @cwd, exit: status.exitstatus }
      unless status.success? || allow_failure
        TutorialReplay.fail!("page command failed (exit #{status.exitstatus}) in #{relative(@cwd)}: #{command}\n#{tail(output)}")
      end
      output
    end

    # Writes a page-shown file relative to the current directory.
    def write_file(path, content)
      target = File.expand_path(path, @cwd)
      @log.call("write #{path}    (in #{relative(@cwd)})")
      FileUtils.mkdir_p(File.dirname(target))
      File.write(target, content)
      @transcript << { file: path, cwd: @cwd }
      target
    end

    # Replays steps in order. `skip` receives each shell command and returns a
    # reason string to skip it (logged), or nil to run it.
    def replay(steps, skip: ->(_command) {}, env: {})
      steps.each do |step|
        if step.file?
          write_file(step.path, step.text)
        elsif (reason = skip.call(step.text))
          @log.call("skip: #{step.text}    (#{reason})")
        else
          run(step.text, env: env)
        end
      end
    end

    def chdir(path)
      @cwd = File.expand_path(path, @cwd)
    end

    def relative(path)
      path == @root ? "." : path.delete_prefix("#{@root}/")
    end

    def tail(output, lines = 60)
      output.lines.last(lines).join
    end
  end

  # Creates a scratch workspace and removes it afterwards unless
  # TUTORIAL_REPLAY_KEEP is set.
  def with_workspace(name, cli_bin: nil, env: {}, log: method(:puts))
    root = Dir.mktmpdir("tutorial-replay-#{name}.")
    workspace = Workspace.new(root: root, cli_bin: cli_bin, env: env, log: log)
    yield workspace
  ensure
    if root && Dir.exist?(root)
      if ENV["TUTORIAL_REPLAY_KEEP"] == "1"
        log.call("kept work dir #{root}")
      else
        FileUtils.remove_entry(root)
      end
    end
  end

  # CARGO_TARGET_DIR for one replay: shared base when configured (CI caches
  # it), otherwise inside the work dir.
  def target_dir(workspace, name)
    base = ENV["TUTORIAL_REPLAY_TARGET_DIR"]
    base && !base.empty? ? File.join(base, name) : File.join(workspace.root, ".target", name)
  end

  # ------------------------------------------------------------------- live app

  # The page's run command with the port replaced: `-p N`, `--port N`,
  # `--port=N`, and `PORT=N` are rewritten, and PORT is exported as well.
  def with_port(command, port)
    command
      .gsub(/(\s-p\s+)\d+/) { "#{Regexp.last_match(1)}#{port}" }
      .gsub(/(\s--port[=\s]+)\d+/) { "#{Regexp.last_match(1)}#{port}" }
      .gsub(/\bPORT=\d+/, "PORT=#{port}")
  end

  # A booted app: spawned in its own process group so `cargo run` and the
  # binary it starts die together.
  class App
    attr_reader :pid, :base_url, :log_path

    def initialize(pid:, port:, log_path:, log:)
      @pid = pid
      @base_url = "http://127.0.0.1:#{port}"
      @log_path = log_path
      @log = log
    end

    def server_log
      File.file?(@log_path) ? File.read(@log_path) : ""
    end

    def alive?
      Process.waitpid(@pid, Process::WNOHANG).nil?
    rescue Errno::ECHILD
      false
    end

    def get(path)
      Net::HTTP.get_response(URI("#{@base_url}#{path}"))
    end

    def get_json(path)
      response = get(path)
      TutorialReplay.fail!("GET #{path} returned #{response.code}: #{response.body.to_s[0, 400]}") unless response.is_a?(Net::HTTPSuccess)
      JSON.parse(response.body)
    end

    def request(method, path, body = nil)
      uri = URI("#{@base_url}#{path}")
      klass = { post: Net::HTTP::Post, delete: Net::HTTP::Delete }.fetch(method)
      request = klass.new(uri)
      if body
        request["Content-Type"] = "application/json"
        request.body = body
      end
      Net::HTTP.start(uri.host, uri.port, read_timeout: 120) { |http| http.request(request) }
    end

    # Waits until GET /health (or /) answers 2xx. Fails when the process dies.
    def wait_for_http(timeout:)
      deadline = Time.now + timeout
      until Time.now > deadline
        TutorialReplay.fail!("app exited before it answered HTTP:\n#{server_log.lines.last(60).join}") unless alive?
        begin
          %w[/health /].each do |path|
            return path if get(path).is_a?(Net::HTTPSuccess)
          end
        rescue SystemCallError, Net::ReadTimeout, EOFError, IOError
          nil
        end
        sleep 2
      end
      TutorialReplay.fail!("app never answered HTTP within #{timeout}s:\n#{server_log.lines.last(60).join}")
    end

    # The demo-data id to solve: the catalog's defaultId, else the first id.
    def default_demo_id
      catalog = get_json("/demo-data")
      case catalog
      when Hash then catalog["defaultId"] || Array(catalog["availableIds"]).first
      when Array then catalog.first
      end || TutorialReplay.fail!("GET /demo-data returned no ids: #{catalog.inspect}")
    end

    # Solves demo data. Returns a hash with :job_id, :state, :score, :job.
    # Waits up to `timeout` seconds for a terminal state; a job still running
    # at the bound is accepted only if it already carries a score, and is
    # cancelled before deletion.
    def solve(demo_id: nil, timeout: 180, require_terminal: false)
      demo_id ||= default_demo_id
      plan = get(+"/demo-data/#{demo_id}")
      TutorialReplay.fail!("GET /demo-data/#{demo_id} returned #{plan.code}") unless plan.is_a?(Net::HTTPSuccess)
      created = request(:post, "/jobs", plan.body)
      TutorialReplay.fail!("POST /jobs returned #{created.code}: #{created.body.to_s[0, 400]}") unless created.is_a?(Net::HTTPSuccess)
      job_id = JSON.parse(created.body).fetch("id").to_s
      @log.call("POST /jobs -> job #{job_id} (demo data #{demo_id})")

      job = nil
      deadline = Time.now + timeout
      loop do
        job = get_json("/jobs/#{job_id}")
        break if TERMINAL_STATES.include?(job["lifecycleState"]) || Time.now > deadline

        sleep 1
      end
      state = job["lifecycleState"]
      score = job["bestScore"] || job["currentScore"]
      @log.call("job #{job_id}: lifecycleState=#{state} score=#{score.inspect} terminalReason=#{job["terminalReason"].inspect}")
      if state == "FAILED"
        TutorialReplay.fail!("job #{job_id} FAILED (#{job["terminalReason"]}):\n#{server_log.lines.last(40).join}")
      end
      TutorialReplay.fail!("job #{job_id} has no score (state #{state})") if score.nil? || score.to_s.empty?
      TutorialReplay.fail!("job #{job_id} did not finish within #{timeout}s (state #{state})") if require_terminal && !TERMINAL_STATES.include?(state)

      { job_id: job_id, state: state, score: score, job: job, demo_id: demo_id }
    end

    # Cancels a running job, waits for it to settle, then deletes it.
    def delete_job(job_id)
      job = get_json("/jobs/#{job_id}")
      unless TERMINAL_STATES.include?(job["lifecycleState"])
        request(:post, "/jobs/#{job_id}/cancel")
        30.times do
          break if TERMINAL_STATES.include?(get_json("/jobs/#{job_id}")["lifecycleState"])

          sleep 1
        end
      end
      response = request(:delete, "/jobs/#{job_id}")
      TutorialReplay.fail!("DELETE /jobs/#{job_id} returned #{response.code}") unless response.is_a?(Net::HTTPSuccess)
      @log.call("DELETE /jobs/#{job_id} -> #{response.code}")
    end

    def stop
      return unless @pid

      begin
        Process.kill("TERM", -@pid)
        Timeout.timeout(20) { Process.wait(@pid) }
      rescue Timeout::Error
        Process.kill("KILL", -@pid)
        Process.wait(@pid)
      rescue Errno::ESRCH, Errno::ECHILD
        nil
      end
      @pid = nil
    end
  end

  # Boots the app with the page's run command on `port` from the workspace's
  # current directory, waits for HTTP, yields the App, and always stops it.
  def boot(workspace, command, port: free_port, env: {}, boot_timeout: 1200, log: method(:puts))
    command = with_port(command, port)
    log_path = File.join(workspace.root, "server-#{port}.log")
    log.call("$ #{command}    (in #{workspace.relative(workspace.cwd)}, port #{port})")
    pid = Process.spawn(workspace.env.merge("PORT" => port.to_s).merge(env), "bash", "-c", command,
                        chdir: workspace.cwd, pgroup: true, out: log_path, err: log_path)
    app = App.new(pid: pid, port: port, log_path: log_path, log: log)
    answered = app.wait_for_http(timeout: boot_timeout)
    log.call("app (pid #{pid}) answers #{answered} on port #{port}")
    yield app
  ensure
    app&.stop
  end

  # Builds, boots, solves and deletes one job: the acceptance a reader gets.
  # Returns the solve result.
  def build_boot_solve(workspace, run_command:, target:, port: free_port, solve_timeout: 180, require_terminal: false, log: method(:puts))
    cargo_env = { "CARGO_TARGET_DIR" => target }
    workspace.run("cargo build --release", env: cargo_env)
    result = nil
    boot(workspace, run_command, port: port, env: cargo_env, log: log) do |app|
      result = app.solve(timeout: solve_timeout, require_terminal: require_terminal)
      app.delete_job(result[:job_id])
    end
    result
  end

  # --------------------------------------------------------- finished example

  # Clones a published repository (e.g. a Hugging Face Space) into `dir`
  # under the workspace's current directory.
  def clone(workspace, url, dir = nil)
    command = ["git clone", url, dir].compact.join(" ")
    workspace.run(command)
  end
end
