# frozen_string_literal: true

# Gates a use-case tutorial page by doing what its reader does.
#
# The page is the only input. Static checks read the page alone; the live run
# replays the page's "Getting Started" section in one terminal-like workspace
# with the published CLI (TutorialReplay), so the reader's path is exercised in
# page order:
#
#   1. the CLI build: every command and every complete file the page shows,
#      then the page's run command boots the app, the page's own `curl`
#      commands run against it, and a demo solve must end non-FAILED with the
#      score the page promises;
#   2. the finished example: the page's `git clone` of the Hugging Face Space
#      and its run command, a demo solve, and every claim the page makes about
#      that repository (dependency and metadata blocks, solver policy, file
#      paths, constraint ids, dataset sizes, release tag) compared with the
#      clone;
#   3. the "Testing and Validation" commands, run in the clone.
#
# Nothing skips silently: a command the gate cannot run (Docker, or a test
# that always fetches fresh data from a public service) is listed by name with
# its reason in the gate's config, logged, and covered by the page's literal
# proof.

require "fileutils"
require "json"
require "set"
require_relative "tutorial_replay"

module UseCaseTutorial
  Config = Struct.new(
    :name,              # log prefix, e.g. "verify-lessons-tutorial"
    :page,              # absolute page path
    :page_url,          # site URL of the page, for the rendered-H1 check
    :cli_version,       # pinned published solverforge-cli the gate installs
    :runtime_version,   # solverforge version the CLI scaffolds and the app uses
    :space_url,         # Hugging Face Space clone URL the page must use
    :app,               # use-case name, e.g. "lessons" (release tag solverforge-<app>@X)
    :cli_section,       # heading of the CLI build section
    :clone_section,     # heading of the finished-example section
    :constraints_section, # heading whose lists/tables name the finished app's constraints
    :validation_section,  # heading of the validation commands
    :not_run,           # { "command" => "why the gate cannot run it" }; logged, proven by hand
    :dataset_table,     # { demo_id_column => ..., "Column" => ->(plan) { count } }
    :cli_score_prefix,  # score prefix the CLI build must reach, e.g. "0hard"
    :banned,            # { "needle" => "why it must not appear" }
    :osm_cache,         # true when the app caches road data in .osm_cache
    :extra_static,      # optional ->(text, gate) { } for page-specific checks
    keyword_init: true
  )

  KNOWN_TYPES = %w[
    String str bool char usize isize u8 u16 u32 u64 u128 i8 i16 i32 i64 i128 f32 f64
    Vec Option Box BTreeSet BTreeMap HashSet HashMap
    NaiveDate NaiveTime NaiveDateTime DateTime Utc Weekday Duration
  ].to_set.freeze

  RUN_COMMAND = /\A(?:PORT=\d+\s+)?(?:solverforge server|make run(?:-release)?|cargo run)\b/
  SOLVE_TIMEOUT = 240

  class Gate
    attr_reader :config, :text

    def initialize(config)
      @config = config
      @text = File.read(config.page)
    end

    def log(message)
      puts "[#{config.name}] #{message}"
    end

    def fail!(message)
      raise TutorialReplay::Failure, message
    end

    def run(argv)
      static = argv.include?("--static")
      check_static
      log "Static page contract passed"
      unless static
        check_live
        log "Live replay passed"
      end
      log "#{File.basename(config.page)} contract checks passed"
    rescue TutorialReplay::Failure => e
      warn "[#{config.name}] ERROR: #{e.message}"
      exit 1
    rescue StandardError => e
      warn "[#{config.name}] ERROR: #{e.class}: #{e.message}\n  #{e.backtrace.first(5).join("\n  ")}"
      exit 1
    end

    # ------------------------------------------------------------------ static

    def getting_started
      @getting_started ||= TutorialReplay.section(text, "Getting Started")
    end

    # The CLI build section; without one, the CLI checks read all of Getting
    # Started (the missing section is reported on its own).
    def cli_text
      @cli_text ||= begin
        TutorialReplay.section(text, config.cli_section)
      rescue TutorialReplay::Failure
        getting_started
      end
    end

    def steps
      @steps ||= TutorialReplay.steps(getting_started)
    end

    # Runs every static check and reports all failures together, so one run
    # shows everything wrong with a page.
    def check_static
      errors = []
      [
        -> { fail!("#{config.cli_section.inspect} must sit under Getting Started") unless getting_started.include?(TutorialReplay.section(text, config.cli_section)) },
        -> { TutorialReplay.section(text, config.clone_section) },
        -> { TutorialReplay.section(text, config.validation_section) },
        -> { check_cli_install },
        -> { check_versions },
        -> { check_directory_flow },
        -> { check_generated_files },
        -> { check_field_types },
        -> { check_banned },
        -> { config.extra_static&.call(text, self) },
        -> { check_rendered_h1 }
      ].each do |check|
        check.call
      rescue TutorialReplay::Failure => e
        errors << e.message
      end
      return if errors.empty?

      fail!("#{errors.size} static check(s) failed:\n  - #{errors.join("\n  - ")}")
    end

    def shell_commands(section_text = getting_started)
      TutorialReplay.steps(section_text).select(&:shell?).map(&:text)
    end

    def check_cli_install
      install = shell_commands.find { |c| c.start_with?("cargo install solverforge-cli") }
      fail!("Getting Started never installs solverforge-cli") unless install
      line = config.cli_version.split(".").first(2).join(".")
      fail!("page must name the CLI line it documents (`solverforge-cli #{line}`)") unless text.include?("solverforge-cli #{line}")
    end

    def check_versions
      fail!("page must state the runtime the CLI scaffolds: solverforge #{config.runtime_version}") unless text.include?("`solverforge #{config.runtime_version}`")
      stale = text.scan(/solverforge(?:-cli)? (\d+\.\d+\.\d+)/).flatten.uniq.reject do |v|
        [config.runtime_version, config.cli_version].include?(v)
      end
      fail!("page names versions it does not document: #{stale.join(", ")}") unless stale.empty?
    end

    # Follows the page's commands as directory moves: `solverforge new` and
    # `git clone` create directories, `cd` must land in one, and a clone must
    # never land inside a scaffolded project.
    def check_directory_flow
      cwd = []
      dirs = Set[[]]
      projects = Set.new
      clones = 0
      shell_commands.each do |command|
        words = command.split
        case command
        when /\Asolverforge new (\S+)/
          dir = cwd + [Regexp.last_match(1)]
          dirs << dir
          projects << dir
        when /\Agit clone /
          url, target = words[2], words[3]
          fail!("page clones #{url}, expected #{config.space_url}") unless url == config.space_url
          target ||= File.basename(url, ".git")
          dir = cwd + [target]
          inside = projects.find { |project| dir[0, project.size] == project }
          fail!("`#{command}` runs inside the scaffold #{inside.join("/")}; the clone would nest in it") if inside
          fail!("`#{command}` clones into #{dir.join("/")}, which already exists") if dirs.include?(dir)
          dirs << dir
          clones += 1
        when /\Acd (\S+)\z/
          target = Regexp.last_match(1)
          cwd = target == ".." ? cwd[0...-1] : cwd + [target]
          fail!("`#{command}` moves into a directory the page never created") unless dirs.include?(cwd) || cwd.empty?
        end
      end
      fail!("Getting Started never clones the finished example") if clones.zero?
    end

    def page_files
      @page_files ||= TutorialReplay.page_files(cli_text)
    end

    def check_generated_files
      generated = shell_commands(cli_text).filter_map { |c| c[/\Asolverforge generate constraint (\w+)/, 1] }
      fail!("#{config.cli_section} generates no constraints") if generated.empty?
      generated.each do |name|
        path = "src/constraints/#{name}.rs"
        body = page_files[path]
        fail!("page generates constraint `#{name}` but never shows #{path}; the generated placeholder panics on every solve") unless body
        fail!("#{path} on the page still contains a placeholder") if body.match?(/replace placeholder|todo!\(|unimplemented!\(/)
      end
      run = shell_commands(cli_text).find { |c| c.match?(RUN_COMMAND) }
      fail!("#{config.cli_section} has no run command") unless run
      fail!("#{config.cli_section} never builds the app") unless shell_commands(cli_text).include?("cargo build")
    end

    def check_field_types
      commands = shell_commands(cli_text)
      commands.grep(/\Asolverforge generate fact /).each do |command|
        %w[id name].each do |builtin|
          fail!("`#{command[0, 60]}...` passes --field #{builtin}:..., which generate fact already adds") if command.match?(/--field "?#{builtin}:/)
        end
      end
      types = commands.flat_map { |c| c.scan(/--field "?\w+:([^"\s]+)/).flatten }
      custom = types.flat_map { |t| t.scan(/[A-Za-z_]\w*/) }.uniq.reject { |t| KNOWN_TYPES.include?(t) }
      manifest = page_files["src/domain/mod.rs"]
      custom.each do |type|
        defined = page_files.any? { |path, body| path.start_with?("src/domain/") && body.match?(/pub (?:struct|enum) #{type}\b/) }
        fail!("field type `#{type}` is never defined in a src/domain file the page shows") unless defined
        fail!("field type `#{type}` is not exported from the src/domain/mod.rs the page shows") unless manifest&.match?(/pub use \w+::#{type};/)
      end
    end

    def check_banned
      (config.banned || {}).each do |needle, why|
        fail!("page still says #{needle.inspect}: #{why}") if text.include?(needle)
      end
    end

    def check_rendered_h1
      rendered = File.join(File.expand_path("../..", __dir__), "output", config.page_url, "index.html")
      return log("Rendered H1 check needs a build; #{rendered} not found") unless File.file?(rendered)

      count = File.read(rendered).scan(/<h1(?:\s|>)/i).size
      fail!("rendered page should have exactly one H1, found #{count}") unless count == 1
    end

    # -------------------------------------------------------------------- live

    def check_live
      cli_bin = TutorialReplay.install_cli(config.cli_version, log: method(:log))
      TutorialReplay.with_workspace(config.app, cli_bin: cli_bin, log: method(:log)) do |workspace|
        @workspace = workspace
        boots = replay_getting_started
        fail!("expected two boots (CLI build and finished example), got #{boots.size}") unless boots.size == 2
        check_cli_result(boots.first)
        check_clone(boots.last)
        replay_validation(boots.last[:dir])
      end
    end

    def cargo_env
      { "CARGO_TARGET_DIR" => TutorialReplay.target_dir(@workspace, File.basename(@workspace.cwd)) }
    end

    # Replays Getting Started in page order. A run command boots the app; the
    # `curl` commands that follow run against it, and the next other command
    # stops it. Returns one record per boot.
    def replay_getting_started
      boots = []
      pending_app = nil
      queue = steps.dup
      until queue.empty?
        step = queue.shift
        if step.file?
          @workspace.write_file(step.path, step.text)
          next
        end
        command = step.text
        if command.start_with?("cargo install solverforge-cli")
          log "skip: #{command}    (solverforge-cli #{config.cli_version} is installed by the gate)"
          next
        end
        if (reason = config.not_run[command])
          log "not run: #{command}    (#{reason}; covered by the page's literal proof)"
          next
        end
        if command.match?(RUN_COMMAND)
          curls = []
          curls << queue.shift.text while queue.first&.shell? && queue.first.text.start_with?("curl ")
          boots << boot_and_solve(command, curls, first: boots.empty?)
          next
        end
        @workspace.run(command, env: cargo_env)
      end
      boots
    end

    def boot_and_solve(command, curls, first:)
      dir = @workspace.cwd
      seed_osm_cache(dir)
      record = { dir: dir, command: command }
      TutorialReplay.boot(@workspace, command, port: UseCaseTutorial.port, env: cargo_env, log: method(:log)) do |app|
        curls.each do |curl|
          @workspace.run(curl.gsub(%r{http://localhost:\d+}, app.base_url))
        end
        check_page_job(app) if curls.any? { |c| c.match?(%r{-X POST .*/jobs\z}) }
        record[:catalog] = app.get_json("/demo-data")
        record[:demo_ids] = demo_ids(record[:catalog])
        record[:demos] = record[:demo_ids].to_h { |id| [id, app.get_json("/demo-data/#{id}")] }
        result = app.solve(timeout: SOLVE_TIMEOUT, require_terminal: first)
        record[:result] = result
        record[:analysis] = app.get_json("/jobs/#{result[:job_id]}/analysis")
        app.delete_job(result[:job_id])
      end
      save_osm_cache(dir)
      record
    end

    # The job the page's own `curl -X POST .../jobs` started (id 0 on a fresh
    # server) must finish without failing.
    def check_page_job(app)
      deadline = Time.now + SOLVE_TIMEOUT
      job = nil
      loop do
        job = app.get_json("/jobs/0")
        break if TutorialReplay::TERMINAL_STATES.include?(job["lifecycleState"]) || Time.now > deadline

        sleep 1
      end
      state = job["lifecycleState"]
      log "page job 0: lifecycleState=#{state} score=#{job["bestScore"].inspect}"
      fail!("the page's job 0 ended #{state}:\n#{app.server_log.lines.last(20).join}") unless state == "COMPLETED"
    end

    def osm_cache_store
      dir = ENV["TUTORIAL_REPLAY_OSM_CACHE"]
      dir && !dir.empty? ? File.join(dir, config.app) : nil
    end

    def seed_osm_cache(dir)
      store = osm_cache_store
      return unless config.osm_cache && store && Dir.exist?(store) && File.file?(File.join(dir, "Cargo.toml"))

      log "Seeding .osm_cache from #{store}"
      FileUtils.cp_r(File.join(store, "."), File.join(dir, ".osm_cache"))
    end

    def save_osm_cache(dir)
      store = osm_cache_store
      source = File.join(dir, ".osm_cache")
      return unless config.osm_cache && store && Dir.exist?(source)

      FileUtils.mkdir_p(store)
      FileUtils.cp_r(File.join(source, "."), store)
    end

    def check_cli_result(boot)
      result = boot[:result]
      fail!("CLI build job ended #{result[:state]}, expected COMPLETED") unless result[:state] == "COMPLETED"
      prefix = config.cli_score_prefix
      fail!("CLI build solved to #{result[:score]}, the page promises #{prefix}") if prefix && !result[:score].start_with?(prefix)
      names = boot[:analysis].dig("analysis", "constraints").map { |c| c["name"] }
      generated = shell_commands(cli_text).filter_map { |c| c[/\Asolverforge generate constraint (\w+)/, 1] }
      fail!("CLI build analysis lists #{names.sort}, the page generates #{generated.sort}") unless names.sort == generated.sort
      log "CLI build: #{result[:state]} #{result[:score]}"
    end

    # ----------------------------------------------------- finished example

    def check_clone(boot)
      dir = boot[:dir]
      result = boot[:result]
      log "Finished example: #{result[:state]} #{result[:score]}"
      check_release_tag(dir)
      check_toml_blocks(dir)
      check_paths(dir)
      check_constraint_ids(dir, boot[:analysis])
      check_dataset_table(boot)
    end

    def clone_read(dir, path)
      full = File.join(dir, path)
      fail!("the finished example has no #{path}") unless File.file?(full)
      File.read(full)
    end

    def check_release_tag(dir)
      version = clone_read(dir, "Cargo.toml")[/^version = "([^"]+)"/, 1]
      tags = text.scan(/solverforge-#{Regexp.escape(config.app)}@(\d+\.\d+\.\d+)/).flatten.uniq
      fail!("page never names the release tag solverforge-#{config.app}@#{version}") if tags.empty?
      fail!("page names release tags #{tags.join(", ")}; the Space is #{version}") unless tags == [version]
    end

    # TOML tables as { "[name]" => [normalized lines] }, comments dropped.
    def toml_tables(source)
      tables = Hash.new { |h, k| h[k] = [] }
      current = "[]"
      joined = +""
      source.each_line do |raw|
        line = raw.sub(/\s+#.*\z/, "").strip
        next if line.empty? || line.start_with?("#")

        if joined.empty? && line.match?(/\A\[\[?[^\]]+\]\]?\z/)
          current = line
          tables[current] ||= []
          next
        end
        joined << line
        next if joined.count("[{") > joined.count("]}")

        tables[current] << joined.gsub(/\s+/, "").sub(/,([\]}])/, '\1')
        joined = +""
      end
      tables
    end

    def check_toml_blocks(dir)
      blocks = TutorialReplay.fenced_blocks(text).select { |b| b.language == "toml" }
      cargo = toml_tables(clone_read(dir, "Cargo.toml"))
      metadata = toml_tables(clone_read(dir, "solverforge.app.toml"))
      solver_source = clone_read(dir, "solver.toml")
      checked = 0
      blocks.each do |block|
        tables = toml_tables(block.body)
        if tables.key?("[dependencies]")
          compare_tables(tables, cargo, "Cargo.toml", block.line)
        elsif tables.key?("[app]")
          compare_tables(tables, metadata, "solverforge.app.toml", block.line)
        elsif tables.key?("[[phases]]") || tables.key?("[termination]")
          expected = solver_source.lines.map(&:strip).reject { |l| l.empty? || l.start_with?("#") }
          actual = block.body.lines.map(&:strip).reject { |l| l.empty? || l.start_with?("#") }
          fail!("solver.toml block at page line #{block.line} is not the finished app's solver.toml") unless actual == expected
        else
          next
        end
        checked += 1
      end
      fail!("page shows no dependency, metadata, or solver TOML block to check") if checked.zero?
      log "#{checked} TOML blocks match the finished example"
    end

    def compare_tables(page_tables, file_tables, file, line)
      page_tables.each do |name, lines|
        next if name == "[]" && lines.empty?

        expected = file_tables.fetch(name) { fail!("#{file} has no #{name} table (page line #{line})") }
        next if lines == expected

        missing = lines - expected
        extra = expected - lines
        fail!("#{name} block at page line #{line} differs from #{file}: page-only #{missing.inspect}, file-only #{extra.inspect}")
      end
    end

    PATH_TOKEN = %r{\A(?:src|static|tests)/[\w./-]+\z|\A(?:solverforge\.app\.toml|solver\.toml|Dockerfile|Makefile|package\.json)\z}

    def check_paths(dir)
      outside_cli = text.sub(cli_text, "")
      prose = outside_cli.gsub(/^```.*?^```$/m, "")
      paths = prose.scan(/`([^`\s]+)`/).flatten.uniq.select { |t| t.match?(PATH_TOKEN) }
      # Files the page has the reader generate (e.g. a new constraint in a
      # customization step) do not exist in the clone yet.
      generated = shell_commands(text).filter_map { |c| c[/\Asolverforge generate constraint (\w+)/, 1] }
      created = generated.map { |name| "src/constraints/#{name}.rs" }
      missing = paths.reject { |p| created.include?(p) || File.exist?(File.join(dir, p.delete_suffix("/"))) }
      fail!("page names paths the finished example does not have: #{missing.join(", ")}") unless missing.empty?
      log "#{paths.size} file paths exist in the finished example"
    end

    def page_constraint_names
      section = TutorialReplay.section(text, config.constraints_section)
      names = section.scan(/^\s*(?:-|\d+\.|\|)\s+`([a-z][a-z0-9_]*)(?:\.rs)?`/).flatten.uniq
      fail!("#{config.constraints_section} names no constraints") if names.empty?
      names
    end

    def check_constraint_ids(dir, analysis)
      names = page_constraint_names
      analyzed = analysis.dig("analysis", "constraints").map { |c| c["name"] }
      modules = Dir[File.join(dir, "src/constraints/*.rs")].map { |f| File.basename(f, ".rs") } - %w[mod]
      unknown = names - modules - analyzed
      fail!("#{config.constraints_section} names constraints the finished app does not have: #{unknown.join(", ")}") unless unknown.empty?
      mentioned = TutorialReplay.section(text, config.constraints_section).scan(/`([a-z][a-z0-9_]*)`/).flatten
      unlisted = analyzed.reject { |n| names.include?(n) || mentioned.include?(n) }
      fail!("the finished app reports constraints the page never names: #{unlisted.join(", ")}") unless unlisted.empty?
      log "#{analyzed.size} analysed constraints match #{config.constraints_section}"
    end

    # Demo ids from either catalog shape the apps serve: an object with
    # `availableIds`, or a bare array of ids.
    def demo_ids(catalog)
      ids = catalog.is_a?(Hash) ? catalog["availableIds"] : catalog
      ids = Array(ids).map { |entry| entry.is_a?(Hash) ? entry["id"] : entry }
      fail!("GET /demo-data lists no ids: #{catalog.inspect}") if ids.empty?
      ids
    end

    # Every row of the page's dataset table against /demo-data/<id>.
    def check_dataset_table(boot)
      table = config.dataset_table or return
      lines = text.lines.map(&:strip)
      header = lines.find { |l| l.start_with?("| Dataset") } || fail!("page has no dataset table")
      columns = header.split("|").map(&:strip).reject(&:empty?)
      rows = lines.select { |l| l.match?(/\A\| `[A-Z_]+`/) }
      page_ids = rows.map { |r| r[/\A\| `([A-Z_]+)`/, 1] }
      fail!("dataset table lists #{page_ids}, the app serves #{boot[:demo_ids]}") unless page_ids.sort == boot[:demo_ids].sort
      rows.each do |row|
        id = row[/\A\| `([A-Z_]+)`/, 1]
        cells = row.split("|").map(&:strip).reject(&:empty?)
        table.each do |column, counter|
          index = columns.index(column) || fail!("dataset table has no #{column} column")
          actual = counter.call(boot[:demos].fetch(id))
          fail!("dataset table says #{column}=#{cells[index]} for #{id}; the app serves #{actual}") unless cells[index] == actual.to_s
        end
      end
      log "Dataset table matches /demo-data for #{page_ids.join(", ")}"
    end

    # -------------------------------------------------------------- validation

    def replay_validation(dir)
      @workspace.chdir(dir)
      commands = shell_commands(TutorialReplay.section(text, config.validation_section))
      fail!("#{config.validation_section} has no commands") if commands.empty?
      install = commands.index("make install-e2e")
      first_test = commands.index { |c| c.start_with?("make test") }
      fail!("#{config.validation_section} must run `make install-e2e` before `make test`") if first_test && (install.nil? || install > first_test)
      commands.each do |command|
        if (reason = config.not_run[command])
          log "not run: #{command}    (#{reason}; covered by the page's literal proof)"
        elsif command.start_with?("curl ")
          log "not run: #{command}    (needs the server; the boot above exercised these routes)"
        else
          # The apps' browser tests bind E2E_PORT (Makefile) or PLAYWRIGHT_PORT
          # (Playwright config); keep both inside the gate's port range.
          ports = { "E2E_PORT" => UseCaseTutorial.port.to_s, "PLAYWRIGHT_PORT" => UseCaseTutorial.port.to_s }
          @workspace.run(command, env: cargo_env.merge(ports))
        end
      end
    end
  end

  # A free port, from TUTORIAL_REPLAY_PORTS ("18600-18699") when set.
  def self.port
    range = ENV["TUTORIAL_REPLAY_PORTS"].to_s[/\A(\d+)-(\d+)\z/] ? Range.new(Regexp.last_match(1).to_i, Regexp.last_match(2).to_i) : nil
    return TutorialReplay.free_port unless range

    range.to_a.shuffle.each do |candidate|
      server = TCPServer.new("127.0.0.1", candidate)
      server.close
      return candidate
    rescue SystemCallError
      next
    end
    raise TutorialReplay::Failure, "no free port in #{range}"
  end

  # Counts the JSON array at the first of `keys` present in a demo plan.
  def self.count(*keys)
    lambda do |plan|
      key = keys.find { |k| plan.key?(k) } || raise(TutorialReplay::Failure, "demo plan has none of #{keys.join(", ")}")
      Array(plan[key]).size
    end
  end

  def self.run(config, argv = ARGV)
    Gate.new(config).run(argv)
  end
end
