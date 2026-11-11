# frozen_string_literal: true

# Reads the Rust blocks of documentation pages and assembles them into the
# Cargo crates a reader would write.
#
# A page declares how each block fits a crate with an HTML comment directly
# above the block (it does not render):
#
#   <!-- rust: crate=NAME file=src/domain/model.rs -->   the whole file
#   <!-- rust: crate=NAME file=src/examples.rs slot=example -->
#                                                         a whole file whose
#                                                         line `// example`
#                                                         takes fragments
#   <!-- rust: crate=NAME in=example -->                  a fragment, compiled
#                                                         in place of that line
#   <!-- rust: crate=NAME excerpt -->                     lines quoted verbatim
#                                                         from a file of NAME
#   <!-- rust: crate=NAME output -->                      (on a text block) the
#                                                         exact stdout of
#                                                         `cargo run`
#   <!-- rust: crate=NAME extends=BASE file=src/main.rs --> NAME starts from
#                                                         every file of BASE
#
# A Rust block without a comment must compile on its own as `src/lib.rs` (or
# `src/main.rs` when it has `fn main`). Nothing is added to a crate except
# `Cargo.toml` (`solverforge = "=VERSION"`, what `cargo add solverforge@=VERSION`
# writes), a `src/lib.rs` made of `pub mod` lines for the page's top-level
# modules when the page shows no crate root, and one module per fragment.
# A crate used on a page other than the one that defines it must be linked
# from that page, so the context a fragment compiles in is always one click
# away from the reader.

require "set"

module RustPages
  class Error < StandardError; end

  ROOT = File.expand_path("../..", __dir__)

  # The published solverforge release every Rust block compiles against.
  # verify-release-surface.rb holds this line to the current release, and the
  # Rust docs index must tell the reader to install exactly this version.
  RELEASE = "0.26.1"
  VERSION_PAGE = "src/docs/solverforge/index.md"
  INSTALL_LINE = "cargo add solverforge@=#{RELEASE}".freeze

  # Contract errors about the install line, empty when the page pins RELEASE.
  def self.install_line_errors(root = ROOT)
    text = File.read(File.join(root, VERSION_PAGE))
    return [] if text.lines.any? { |line| line.strip == INSTALL_LINE }

    ["#{VERSION_PAGE}: the install command must be `#{INSTALL_LINE}`, the release these pages compile against"]
  end

  Block = Struct.new(:page, :line, :code_line, :lang, :code, :marker, keyword_init: true) do
    def where = "#{page}:#{line}"
    def rust? = %w[rust rs].include?(lang)
  end

  class Marker
    KEYS = %w[crate file in slot extends].freeze
    FLAGS = %w[excerpt output].freeze

    attr_reader :values, :flags

    def initialize(values, flags)
      @values = values
      @flags = flags
    end

    def self.parse(body, where)
      values = {}
      flags = Set.new
      body.scan(/(\w+)=("([^"]*)"|\S+)|(\S+)/).each do |key, raw, quoted, flag|
        if key
          raise Error, "#{where}: unknown rust marker key `#{key}`" unless KEYS.include?(key)

          values[key] = quoted || raw
        else
          raise Error, "#{where}: unknown rust marker flag `#{flag}`" unless FLAGS.include?(flag)

          flags << flag
        end
      end
      new(values, flags)
    end

    def [](key) = values[key]
    def flag?(name) = flags.include?(name)
  end

  # Extracts fenced and ERB code blocks with their markers.
  class Extractor
    FENCE = /^```([\w-]*)[^\n]*\n(.*?)^```[ \t]*$/m
    ERB_BLOCK = /<%=\s*render\s+Ui::CodeBlock\.new\([^%]*language:\s*["'](\w+)["'][^%]*\)\s*do\s*%>[ \t]*\n(.*?)^[ \t]*<%\s*end\s*%>/m
    MARKER = /<!--\s*rust:\s*((?:(?!-->).)*?)\s*-->\s*\z/m

    attr_reader :errors

    def initialize(root)
      @root = root
      @errors = []
    end

    def blocks(page)
      text = File.read(File.join(@root, page))
      text.to_enum(:scan, /<!--\s*sf-rust:/).each do
        line = text[0...Regexp.last_match.begin(0)].count("\n") + 1
        @errors << "#{page}:#{line}: `sf-rust` markers are not supported (nothing is skipped); use `<!-- rust: ... -->`"
      end

      found = []
      text.to_enum(:scan, FENCE).each do
        match = Regexp.last_match
        found << [match.begin(0), match[1], match[2], match.begin(2)]
      end
      text.to_enum(:scan, ERB_BLOCK).each do
        match = Regexp.last_match
        found << [match.begin(0), match[1], unindent(match[2]), match.begin(2)]
      end

      found.sort_by(&:first).filter_map do |offset, lang, code, code_offset|
        line = text[0...offset].count("\n") + 1
        prefix = text[0...offset].rstrip
        marker = nil
        if prefix.match(MARKER)
          begin
            marker = Marker.parse(Regexp.last_match(1), "#{page}:#{line}")
          rescue Error => e
            @errors << e.message
            next
          end
        end
        Block.new(
          page: page, line: line, code_line: text[0...code_offset].count("\n") + 1,
          lang: lang.to_s.downcase, code: code.sub(/\n+\z/, "\n"), marker: marker
        )
      end
    end

    private

    def unindent(code)
      lines = code.lines
      indent = lines.reject { |line| line.strip.empty? }.map { |line| line[/\A */].size }.min || 0
      lines.map { |line| line.sub(/\A {0,#{indent}}/, "") }.join
    end
  end

  CrateFile = Struct.new(:path, :code, :block, :slot, keyword_init: true)

  class Crate
    attr_reader :name, :files, :fragments, :excerpts, :outputs, :uses
    attr_accessor :extends, :home

    def initialize(name)
      @name = name
      @files = {}
      @fragments = []
      @excerpts = []
      @outputs = []
      @uses = []
    end

    def package = "sf-#{name}"
    def binary?(all) = all_files(all).key?("src/main.rs")

    # This crate's files, after the files of the crate it extends.
    def all_files(all)
      inherited = extends ? all.fetch(extends).all_files(all) : {}
      clash = inherited.keys & files.keys
      raise Error, "crate #{name} redefines #{clash.join(', ')} from #{extends}" unless clash.empty?

      inherited.merge(files)
    end

    def blocks = files.values.map(&:block) + fragments + excerpts + outputs
  end

  # Turns page blocks into crates and checks every marker's contract that does
  # not need a compiler: slots, excerpts, cross-page links.
  class Plan
    attr_reader :crates, :blocks, :version, :errors

    def initialize(root, pages, version)
      @root = root
      @pages = pages
      @version = version
      @crates = {}
      @blocks = []
      @errors = []
    end

    def build!
      extractor = Extractor.new(@root)
      @pages.each do |page|
        standalone = 0
        extractor.blocks(page).each do |block|
          if block.marker.nil?
            next unless block.rust?

            standalone += 1
            add_standalone(block, standalone)
          else
            begin
              add_marked(block)
            rescue Error => e
              @errors << e.message
              next
            end
          end
          @blocks << block
        end
      end
      @errors.concat(extractor.errors)
      validate!
      self
    end

    def rust_blocks = @blocks.select(&:rust?)

    def page_url(page)
      path = page.sub(%r{\Asrc/}, "/").sub(/\.md\z/, "/")
      path.sub(%r{/index/\z}, "/")
    end

    private

    def crate(name, block)
      raise Error, "#{block.where}: crate name `#{name}` must be lowercase letters, digits and dashes" unless name.match?(/\A[a-z][a-z0-9-]*\z/)

      @crates[name] ||= Crate.new(name)
    end

    def add_standalone(block, index)
      slug = block.page.sub(%r{\Asrc/}, "").sub(/\.md\z/, "").gsub(/[^a-z0-9]+/, "-")
      name = "#{slug}-#{format('%02d', index)}".sub(/\A-+/, "")
      target = crate(name, block)
      target.home = block.page
      path = block.code.match?(/\bfn main\s*\(/) ? "src/main.rs" : "src/lib.rs"
      target.files[path] = CrateFile.new(path: path, code: block.code, block: block)
    end

    def add_marked(block)
      marker = block.marker
      name = marker["crate"] or raise Error, "#{block.where}: rust marker needs crate=NAME"
      target = crate(name, block)
      if marker["extends"]
        if target.extends && target.extends != marker["extends"]
          raise Error, "#{block.where}: crate #{name} already extends #{target.extends}"
        end
        target.extends = marker["extends"]
      end
      target.uses << block

      if marker.flag?("output")
        raise Error, "#{block.where}: an output marker belongs on a text block" if block.rust?

        target.outputs << block
        return
      end

      roles = [marker["file"], marker["in"], (true if marker.flag?("excerpt"))].compact
      raise Error, "#{block.where}: give exactly one of file=, in=, excerpt" unless roles.size == 1
      raise Error, "#{block.where}: only Rust blocks can be compiled" unless block.rust?

      if (path = marker["file"])
        raise Error, "#{block.where}: #{name} already has #{path} (#{target.files[path].block.where})" if target.files.key?(path)
        raise Error, "#{block.where}: file= must be a path under src/" unless path.match?(%r{\Asrc/[\w/]+\.rs\z})

        target.home ||= block.page
        target.files[path] = CrateFile.new(path: path, code: block.code, block: block, slot: marker["slot"])
      elsif marker["in"]
        raise Error, "#{block.where}: slot= belongs on the file= block" if marker["slot"]

        target.fragments << block
      else
        target.excerpts << block
      end
    end

    def validate!
      @crates.each_value do |crate|
        if crate.home.nil?
          @errors << "crate #{crate.name} is used (#{crate.uses.first&.where}) but no page shows any of its files"
          next
        end
        if crate.extends && !@crates.key?(crate.extends)
          @errors << "crate #{crate.name} extends unknown crate #{crate.extends}"
          next
        end

        begin
          files = crate.all_files(@crates)
        rescue Error => e
          @errors << e.message
          next
        end
        check_links!(crate)
        check_fragments!(crate, files)
        check_excerpts!(crate, files)
        check_model!(crate, files)
        if crate.outputs.any? && !files.key?("src/main.rs")
          @errors << "#{crate.outputs.first.where}: crate #{crate.name} has an output block but no src/main.rs"
        end
      end
    end

    def check_links!(crate)
      homes = [crate.home]
      homes << @crates.fetch(crate.extends).home if crate.extends
      crate.uses.each do |block|
        homes.uniq.each do |home|
          next if block.page == home

          url = page_url(home)
          text = File.read(File.join(@root, block.page))
          unless text.include?("](#{url})") || text.include?("](#{url}#")
            @errors << "#{block.where}: uses crate #{crate.name} from #{home} but the page never links #{url}"
          end
        end
      end
    end

    def check_fragments!(crate, files)
      crate.fragments.each do |block|
        slot = block.marker["in"]
        owners = files.values.select { |file| file.slot == slot }
        if owners.size != 1
          @errors << "#{block.where}: crate #{crate.name} has #{owners.size} slots named `#{slot}`, needs exactly one"
          next
        end

        owner = owners.first
        count = owner.code.lines.count { |line| line.strip == "// #{slot}" }
        @errors << "#{owner.block.where}: slot `#{slot}` needs exactly one `// #{slot}` line, found #{count}" unless count == 1
      end
    end

    def check_excerpts!(crate, files)
      crate.excerpts.each do |block|
        wanted = block.code.lines.map(&:strip)
        found = files.values.any? do |file|
          have = file.code.lines.map(&:strip)
          (0..(have.size - wanted.size)).any? { |start| have[start, wanted.size] == wanted }
        end
        @errors << "#{block.where}: excerpt is not verbatim in any file of crate #{crate.name}" unless found
      end
    end

    def check_model!(crate, files)
      solution = files.values.find { |file| file.code.include?("#[planning_solution") }
      return unless solution
      return if files.values.any? { |file| file.code.include?("planning_model!") }

      @errors << "#{solution.block.where}: crate #{crate.name} declares a #[planning_solution] " \
                   "but the page never shows the `solverforge::planning_model!` manifest that registers it"
    end
  end

  # Writes a Cargo workspace for a set of crates and maps generated lines back
  # to page lines.
  class Workspace
    Segment = Struct.new(:first, :last, :block, :offset, keyword_init: true)

    attr_reader :dir, :line_map

    def initialize(dir, plan, crates)
      @dir = dir
      @plan = plan
      @crates = crates
      @line_map = {}
    end

    def write!
      members = @crates.map(&:package)
      File.write(File.join(@dir, "Cargo.toml"), <<~TOML)
        [workspace]
        resolver = "3"
        members = [#{members.map { |member| %("#{member}") }.join(', ')}]
      TOML
      @crates.each { |crate| write_crate(crate) }
      self
    end

    def locate(path, line)
      segments = @line_map[File.expand_path(path)] or return nil
      segment = segments.find { |candidate| (candidate.first..candidate.last).cover?(line) } or return nil
      [segment.block, segment.block.code_line + line - segment.first + segment.offset]
    end

    private

    def write_crate(crate)
      root = File.join(@dir, crate.package)
      FileUtils.mkdir_p(File.join(root, "src"))
      File.write(File.join(root, "Cargo.toml"), <<~TOML)
        [package]
        name = "#{crate.package}"
        version = "0.1.0"
        edition = "2024"

        [dependencies]
        solverforge = "=#{@plan.version}"
      TOML

      files = crate.all_files(@plan.crates)
      files.each_value { |file| emit(root, file.path, [[file.code, file.block, 0]]) }

      root_file = %w[src/main.rs src/lib.rs].find { |path| files.key?(path) }
      fragment_mods = crate.fragments.filter_map { |block| write_fragment(root, files, block) }
      if root_file
        unless fragment_mods.empty?
          File.open(File.join(root, root_file), "a") { |io| io.puts("", *fragment_mods) }
        end
      else
        modules = files.keys.filter_map { |path| path[%r{\Asrc/(\w+)(?:\.rs|/mod\.rs)\z}, 1] }.uniq.sort
        lib = modules.map { |name| "pub mod #{name};" } + fragment_mods
        File.write(File.join(root, "src/lib.rs"), lib.join("\n") + "\n")
      end
    end

    def write_fragment(root, files, block)
      slot = block.marker["in"]
      owner = files.values.find { |file| file.slot == slot }
      return nil unless owner && owner.code.match?(/^[ \t]*\/\/ #{Regexp.escape(slot)}[ \t]*$/)

      before, after = owner.code.split(/^[ \t]*\/\/ #{Regexp.escape(slot)}[ \t]*\n/, 2)
      indent = owner.code[/^([ \t]*)\/\/ #{Regexp.escape(slot)}[ \t]*$/, 1]
      body = block.code.lines.map { |line| line.strip.empty? ? "\n" : indent + line }.join
      name = "fragment_#{block.page.gsub(/[^a-z0-9]+/i, '_')}_#{block.line}".downcase
      path = "src/fragments/#{name}.rs"
      slot_line = before.lines.size
      emit(root, path, [[before, owner.block, 0], [body, block, 0], [after.to_s, owner.block, slot_line + 1]])
      %(#[path = "fragments/#{name}.rs"] mod #{name};)
    end

    def emit(root, relative, parts)
      path = File.join(root, relative)
      FileUtils.mkdir_p(File.dirname(path))
      segments = []
      text = +""
      parts.each do |code, block, offset|
        first = text.lines.size + 1
        text << code
        segments << Segment.new(first: first, last: text.lines.size, block: block, offset: offset)
      end
      File.write(path, text)
      @line_map[File.expand_path(path)] = segments
    end
  end
end
