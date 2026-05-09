#!/usr/bin/env ruby
# frozen_string_literal: true

require "fileutils"
require "open3"
require "optparse"
require "shellwords"
require "tmpdir"

ROOT = File.expand_path("..", __dir__)
DEFAULT_SOLVERFORGE_RS_REPO = "/srv/lab/dev/solverforge/solverforge-rs"
DEFAULT_SOLVERFORGE_MAPS_REPO = "/srv/lab/dev/solverforge/solverforge-maps"
DEFAULT_SOLVERFORGE_UI_REPO = "/srv/lab/dev/solverforge/solverforge-ui"

Snippet = Struct.new(
  :id,
  :path,
  :line,
  :kind,
  :raw_code,
  :directive,
  :profile,
  :fixture,
  :compile_mode,
  :status,
  :reason,
  keyword_init: true
) do
  def relpath
    path.delete_prefix("#{ROOT}/")
  end
end

class VerificationError < StandardError; end

class Directive
  VALUE_KEYS = %w[profile fixture reason].freeze
  FLAG_KEYS = %w[fragment ignore].freeze
  ACCEPTED_KEYS = (VALUE_KEYS + FLAG_KEYS).freeze

  attr_reader :values, :flags, :source

  def initialize(values:, flags:, source:)
    @values = values
    @flags = flags
    @source = source
  end

  def self.parse(body, source:)
    values = {}
    flags = {}
    body.scan(/(\w+)\s*=\s*"([^"]*)"|(\w+)/).each do |value_key, value, flag_key|
      key = value_key || flag_key
      unless ACCEPTED_KEYS.include?(key)
        raise VerificationError, "#{source}: unknown sf-rust directive key `#{key}`"
      end

      if value_key
        unless VALUE_KEYS.include?(key)
          raise VerificationError, "#{source}: sf-rust directive key `#{key}` does not accept a value"
        end
        values[key] = value
      else
        unless FLAG_KEYS.include?(key)
          raise VerificationError, "#{source}: sf-rust directive key `#{key}` requires a quoted value"
        end
        flags[key] = true
      end
    end

    directive = new(values: values, flags: flags, source: source)
    if directive.ignore? && directive.reason.to_s.strip.empty?
      raise VerificationError, "#{source}: sf-rust ignore requires reason=\"...\""
    end
    directive
  end

  def profile = values["profile"]
  def fixture = values["fixture"]
  def reason = values["reason"]
  def fragment? = flags["fragment"]
  def ignore? = flags["ignore"]

  def to_s
    parts = values.map { |key, value| %(#{key}="#{value}") } + flags.keys
    parts.empty? ? "(none)" : parts.join(" ")
  end
end

class Extractor
  ERB_RUST_BLOCK = /
    <%=\s*render\s+Ui::CodeBlock\.new\([^%]*language:\s*["']rust["'][^%]*\)\s*do\s*%>
    \n?
    (.*?)
    <%\s*end\s*%>
  /mx

  MARKDOWN_RUST_FENCE = /^```(?:rust|rs)\b[^\n]*\n(.*?)^```/m

  def extract
    snippets = []
    counts = Hash.new(0)
    source_files.each do |path|
      text = File.read(path)
      entries = []

      text.to_enum(:scan, MARKDOWN_RUST_FENCE).each do
        entries << [$~.begin(0), :markdown_fence, $1]
      end

      text.to_enum(:scan, ERB_RUST_BLOCK).each do
        entries << [$~.begin(0), :erb_code_block, unindent_erb_code($1)]
      end

      entries.sort_by(&:first).each do |offset, kind, code|
        relpath = path.delete_prefix("#{ROOT}/")
        counts[relpath] += 1
        line = text[0...offset].count("\n") + 1
        id = "#{slug(relpath)}_%03d" % counts[relpath]
        snippets << Snippet.new(
          id: id,
          path: path,
          line: line,
          kind: kind,
          raw_code: code.rstrip,
          directive: nearby_directive(text, offset, relpath, line)
        )
      end
    end
    snippets
  end

  private

  def source_files
    Dir.glob(File.join(ROOT, "{src/docs,src/reference,src/_posts}/**/*.{md,html,erb}"), File::FNM_EXTGLOB).sort
  end

  def slug(path)
    path
      .sub(/\A(?:src\/)?/, "")
      .gsub(/[^a-zA-Z0-9]+/, "_")
      .gsub(/\A_+|_+\z/, "")
      .downcase
  end

  def nearby_directive(text, offset, relpath, line)
    prefix = text[0...offset].lines.last(5)&.join || ""
    if prefix =~ /<!--\s*sf-rust:\s*(.*?)\s*-->\s*\z/m
      return Directive.parse($1, source: "#{relpath}:#{line}")
    end

    first_lines = text[offset..]&.lines&.first(8)&.join || ""
    if first_lines =~ %r{//\s*sf-rust:\s*(.*)$}
      return Directive.parse($1, source: "#{relpath}:#{line}")
    end

    nil
  end

  def unindent_erb_code(code)
    lines = code.lines
    nonempty = lines.reject { |line| line.strip.empty? }
    indent = nonempty.map { |line| line[/\A */].size }.min || 0
    lines.map { |line| line.sub(/\A {0,#{indent}}/, "") }.join
  end
end

class ProfileResolver
  HISTORICAL_PROFILES = {
    "src/_posts/releases/2026-01-15-solverforge-0-5-x.md" => "solverforge@0.5.0",
    "src/_posts/releases/2026-01-24-solverforge-maps-1-0-x.md" => "solverforge-maps@1.0.0",
    "src/_posts/releases/2026-04-11-solverforge-0-8-x.md" => "solverforge@0.8.2",
    "src/_posts/releases/2026-04-24-solverforge-0-9-x.md" => "solverforge@0.9.0",
    "src/_posts/releases/2026-05-02-solverforge-0-10-x.md" => "solverforge@0.10.0",
    "src/_posts/releases/2026-05-05-solverforge-0-11-x.md" => "solverforge@0.11.1"
  }.freeze

  KNOWN_PROFILES = %w[
    solverforge-current
    solverforge-maps-current
    solverforge-ui-current
    solverforge@0.5.0
    solverforge@0.8.2
    solverforge@0.9.0
    solverforge@0.10.0
    solverforge@0.11.1
    solverforge-maps@1.0.0
    solverforge-maps@2.1.4
  ].freeze

  KNOWN_FIXTURES = %w[
    constraint-streams
    projection
    solver-manager
    modeling
    configuration
    score-types
    maps-routing
    ui-axum
  ].freeze

  def resolve!(snippet)
    snippet.profile = snippet.directive&.profile || inferred_profile(snippet)
    snippet.fixture = snippet.directive&.fixture || inferred_fixture(snippet)
    snippet.compile_mode = inferred_mode(snippet)

    unless KNOWN_PROFILES.include?(snippet.profile)
      raise VerificationError, "#{snippet.relpath}:#{snippet.line}: unknown Rust snippet profile `#{snippet.profile}`"
    end

    unless KNOWN_FIXTURES.include?(snippet.fixture)
      raise VerificationError, "#{snippet.relpath}:#{snippet.line}: unknown Rust snippet fixture `#{snippet.fixture}`"
    end

    if snippet.directive&.ignore?
      snippet.status = :ignored
      snippet.reason = snippet.directive.reason
      return
    end

    if (reason = audited_reason(snippet))
      snippet.status = :audited
      snippet.reason = reason
      return
    end

    snippet.status = :compile
  end

  private

  def inferred_profile(snippet)
    path = snippet.relpath
    return HISTORICAL_PROFILES.fetch(path) if HISTORICAL_PROFILES.key?(path)
    return "solverforge-maps-current" if path.start_with?("src/docs/solverforge-maps/")
    return "solverforge-maps-current" if path.end_with?("2026-05-03-solverforge-maps-2-1-x.md")
    return "solverforge-ui-current" if path.start_with?("src/docs/solverforge-ui/")

    "solverforge-current"
  end

  def inferred_fixture(snippet)
    path = snippet.relpath
    code = snippet.raw_code
    return "maps-routing" if snippet.profile.start_with?("solverforge-maps")
    return "ui-axum" if snippet.profile == "solverforge-ui-current"
    return "solver-manager" if path.include?("/solver-manager.md") || code.include?("SolverManager")
    return "configuration" if path.include?("/solver/configuration.md") || code.include?("SolverConfig")
    return "projection" if path.include?("projected-scoring-rows") || code.include?("ProjectionSink") || code.include?("AssignmentCapacity")
    return "projection" if code.include?("Plan::assignments()") || code.include?("Plan::capacities()")
    return "projection" if code.include?(".assignments()") || code.include?(".capacities()")
    return "score-types" if path.include?("/score-types.md") || code.match?(/\b(?:SoftScore|HardSoftScore|BendableScore)\b/)
    return "modeling" if path.include?("/modeling/") || path.include?("solverforge-cli/")

    "constraint-streams"
  end

  def inferred_mode(snippet)
    return :ignore if snippet.directive&.ignore?
    return :fragment if snippet.directive&.fragment?
    return :field_fragment if field_fragment?(snippet.raw_code)
    return :item if item_snippet?(snippet.raw_code)

    :fragment
  end

  def audited_reason(snippet)
    path = snippet.relpath
    code = snippet.raw_code

    return "historical release snippet is pinned to #{snippet.profile}; current API drift is not hidden" if snippet.profile.include?("@")
    return "file tree excerpt, not Rust source" if path.end_with?("solverforge-cli/project-anatomy.md")
    return "planning_model! composition excerpt; generated tutorial verifiers cover scaffolded output" if code.include?("planning_model!")
    return "field attribute fragment; spelling is checked and full model examples are compiled elsewhere" if field_fragment?(code)
    return "per-solution config macro excerpt; builder/parser snippets compile the SolverConfig API directly" if code.include?('config = "')
    if code.lstrip.start_with?("#[planning_solution") && !code.include?('constraints = "define_constraints"')
      return "planning_solution declaration excerpt; full same-source examples are compiled with generated accessors"
    end
    return "macro declaration excerpt uses application module paths that are not valid in the temporary verifier crate" if code.include?('constraints = "crate::')
    return "list-variable macro excerpt depends on full routing model support outside this local snippet" if code.include?("#[planning_list_variable")
    return "solver-manager lifecycle fragment depends on a live retained job established by the surrounding prose" if partial_solver_manager?(path, code)
    return "generated CLI model excerpt is validated by tutorial/scaffold gates" if path.start_with?("src/docs/solverforge-cli/")
    return "getting-started domain excerpt is validated by the dedicated tutorial verifier" if path.start_with?("src/docs/getting-started/")

    nil
  end

  def item_snippet?(code)
    stripped = code.lstrip
    return true if stripped.start_with?("#[", "pub struct ", "struct ", "impl ", "fn ", "pub fn ", "static ", "const ")
    stripped.include?("\nfn ") || stripped.include?("\npub struct ") || stripped.include?("\n#[planning_")
  end

  def field_fragment?(code)
    stripped = code.lstrip
    stripped.start_with?("#[planning_id]", "#[planning_variable", "#[planning_list_variable", "#[planning_pin]", "#[inverse_relation_shadow_variable", "#[previous_element_shadow_variable", "#[next_element_shadow_variable", "#[planning_entity_collection]", "#[problem_fact_collection]", "#[planning_score]")
  end

  def partial_solver_manager?(path, code)
    return false unless path.include?("/solver-manager.md")
    return false if code.include?("static MANAGER")
    return false if code.include?("use solverforge::SolverEvent")

    true
  end
end

class PolicyGate
  CURRENT_PATHS = [
    "src/docs/solverforge/",
    "src/docs/overview.md",
    "src/docs/getting-started/",
    "src/docs/solverforge-cli/",
    "src/reference/",
    "src/_posts/releases/2026-05-08-solverforge-0-12-x.md"
  ].freeze

  def check!(snippets)
    snippets.each do |snippet|
      current = CURRENT_PATHS.any? { |prefix| snippet.relpath.start_with?(prefix) || snippet.relpath == prefix }
      next unless current

      code = snippet.raw_code
      stale!(snippet, "factory.clone() is forbidden in current SolverForge documentation") if code.include?("factory.clone()")
      stale!(snippet, "raw factory.for_each(|...) closures are forbidden; use generated sources or stream::vec") if code.match?(/factory\.for_each\s*\(\s*\|/)
      stale!(snippet, "factory collection extension methods are stale; use for_each(Solution::collection())") if code.match?(/\b(?:factory|Streams::new\(\))\s*\.(?:shifts|employees|assignments|capacities|vehicles|unavailability)\(\)/)
      stale!(snippet, "value_range = is stale; use value_range_provider") if code.match?(/\bvalue_range\s*=/)
    end
  end

  private

  def stale!(snippet, message)
    raise VerificationError, "#{snippet.relpath}:#{snippet.line}: #{message}"
  end
end

class CargoWorkspaceBuilder
  def initialize(snippets, verbose:, keep_temp:)
    @snippets = snippets
    @verbose = verbose
    @keep_temp = keep_temp
    @tempdir = Dir.mktmpdir("solverforge-rust-snippets.")
  end

  attr_reader :tempdir

  def verify!
    @snippets.select { |snippet| snippet.status == :compile }
      .group_by(&:profile)
      .each { |profile, snippets| verify_profile!(profile, snippets) }
  ensure
    FileUtils.rm_rf(@tempdir) unless @keep_temp
  end

  private

  def verify_profile!(profile, snippets)
    crate_dir = write_crate(profile, snippets)
    ok, stderr = cargo_check(crate_dir)
    return if ok

    snippets.each do |snippet|
      one_dir = write_crate(profile, [snippet], suffix: snippet.id)
      single_ok, single_stderr = cargo_check(one_dir)
      next if single_ok

      report_failure(snippet, one_dir, single_stderr.empty? ? stderr : single_stderr)
    end

    report_failure(snippets.first, crate_dir, stderr)
  end

  def write_crate(profile, snippets, suffix: nil)
    dir_name = suffix || profile.tr("@.-", "___")
    crate_dir = File.join(@tempdir, dir_name)
    FileUtils.mkdir_p(File.join(crate_dir, "src"))
    FileUtils.mkdir_p(File.join(crate_dir, "static"))
    File.write(File.join(crate_dir, "Cargo.toml"), cargo_toml(profile, dir_name))
    File.write(File.join(crate_dir, "src/lib.rs"), lib_rs(profile, snippets))
    File.write(File.join(crate_dir, "static/index.html"), "<!doctype html><title>snippet</title>\n")
    crate_dir
  end

  def cargo_toml(profile, package_name)
    case profile
    when "solverforge-current"
      repo = ENV.fetch("SOLVERFORGE_RS_REPO", DEFAULT_SOLVERFORGE_RS_REPO)
      solverforge_path = File.join(repo, "crates/solverforge")
      require_path!(solverforge_path, "SOLVERFORGE_RS_REPO")
      <<~TOML
        [package]
        name = "#{package_name}"
        version = "0.0.0"
        edition = "2021"

        [dependencies]
        solverforge = { path = "#{solverforge_path}" }
        tokio = { version = "1", features = ["rt", "rt-multi-thread", "macros", "sync"] }
      TOML
    when "solverforge-maps-current"
      repo = ENV.fetch("SOLVERFORGE_MAPS_REPO", DEFAULT_SOLVERFORGE_MAPS_REPO)
      require_path!(repo, "SOLVERFORGE_MAPS_REPO")
      <<~TOML
        [package]
        name = "#{package_name}"
        version = "0.0.0"
        edition = "2021"

        [dependencies]
        solverforge-maps = { path = "#{repo}" }
        tokio = { version = "1", features = ["rt", "rt-multi-thread", "macros"] }
      TOML
    when "solverforge-ui-current"
      repo = ENV.fetch("SOLVERFORGE_UI_REPO", DEFAULT_SOLVERFORGE_UI_REPO)
      require_path!(repo, "SOLVERFORGE_UI_REPO")
      <<~TOML
        [package]
        name = "#{package_name}"
        version = "0.0.0"
        edition = "2021"

        [dependencies]
        solverforge-ui = { path = "#{repo}" }
        axum = "0.8.9"
        tokio = { version = "1", features = ["rt", "rt-multi-thread", "macros"] }
      TOML
    else
      raise VerificationError, "profile #{profile} is audited-only and has no generated Cargo crate"
    end
  end

  def lib_rs(profile, snippets)
    renderer = SnippetRenderer.new(profile)
    <<~RS
      #![allow(dead_code, unused_imports, unused_variables, unused_mut)]
      #![allow(non_snake_case, non_camel_case_types, clippy::all)]

      #{renderer.fixture}

      #{snippets.map { |snippet| renderer.render(snippet) }.join("\n\n")}
    RS
  end

  def cargo_check(crate_dir)
    command = ["cargo", "check", "--quiet", "--lib"]
    env = {
      "CARGO_TARGET_DIR" => File.join(@tempdir, "target")
    }
    stdout, stderr, status = Open3.capture3(env, *command, chdir: crate_dir)
    puts stdout unless stdout.empty? || !@verbose
    puts stderr unless stderr.empty? || !@verbose
    [status.success?, stderr]
  end

  def report_failure(snippet, crate_dir, stderr)
    lines = [
      "[verify-rust-snippets] ERROR",
      "source: #{snippet.relpath}:#{snippet.line}",
      "snippet: #{snippet.id}",
      "profile: #{snippet.profile}",
      "fixture: #{snippet.fixture}",
      "mode: #{snippet.compile_mode}",
      "directive: #{snippet.directive || "(none)"}"
    ]
    lines << "generated crate: #{crate_dir}" if @keep_temp
    lines << ""
    lines << stderr
    raise VerificationError, lines.join("\n")
  end

  def require_path!(path, env_name)
    return if File.directory?(path)

    raise VerificationError, "#{env_name} points to missing path: #{path}"
  end
end

class SnippetRenderer
  def initialize(profile)
    @profile = profile
  end

  def fixture
    case @profile
    when "solverforge-current" then core_fixture
    when "solverforge-maps-current" then maps_fixture
    when "solverforge-ui-current" then ui_fixture
    else ""
    end
  end

  def render(snippet)
    body = case @profile
           when "solverforge-current" then render_core(snippet)
           when "solverforge-maps-current" then render_maps(snippet)
           when "solverforge-ui-current" then render_ui(snippet)
           else raise VerificationError, "unsupported compile profile #{@profile}"
           end

    <<~RS
      // source: #{snippet.relpath}:#{snippet.line}
      pub mod #{module_name(snippet)} {
      #{indent(body, 4)}
      }
    RS
  end

  private

  def module_name(snippet)
    snippet.id.gsub(/[^a-zA-Z0-9_]/, "_")
  end

  def render_core(snippet)
    code = snippet.raw_code
    prelude = <<~RS
      use super::*;
      use solverforge::prelude::*;
      use solverforge::stream::{joiner::*, ConstraintFactory};
      use solverforge::stream::vec;
      use solverforge::{SolverConfig, SolverEvent, SolverManager};
    RS
    item_prelude = <<~RS
      use super::*;
    RS
    item_prelude += "use solverforge::prelude::*;\n" unless code.include?("solverforge::prelude")
    item_prelude += "use solverforge::stream::{joiner::*, ConstraintFactory};\n" unless code.include?("solverforge::stream")
    item_prelude += "use solverforge::{SolverConfig, SolverEvent, SolverManager};\n" if code.include?("SolverManager") && !code.include?("solverforge::{")
    item_prelude += "use solverforge::SolverConfig;\n" if code.include?("SolverConfig") && !code.include?("solverforge::SolverConfig")

    if score_expression_list?(snippet)
      return prelude + "\n" + wrap_function(score_expression_lines(code), snippet)
    end

    if simple_expression_list?(code)
      return prelude + "\n" + wrap_function(expression_lines(code), snippet)
    end

    if typed_stream_expression_list?(code)
      return prelude + "\n" + wrap_function(typed_expression_lines(code), snippet)
    end

    if code.lstrip.start_with?(".")
      return prelude + "\n" + wrap_function("let _constraint = ConstraintFactory::<Schedule, HardSoftScore>::new().for_each(Schedule::shifts())\n#{code}", snippet)
    end

    if code.lstrip.start_with?("equal(", "equal_bi(", "less_than(", "greater_than(", "overlapping(", "filtering(")
      return prelude + "\n" + wrap_function("let _joiner = #{code}", snippet)
    end

    if code.include?("fn main")
      suffix = if code.include?("#[planning_solution") && code.include?("pub struct Plan") && !code.include?("PlanningModelSupport")
                 "\n#{planning_model_support_impl("Plan")}"
               else
                 ""
               end
      return item_prelude + "\n" + code + suffix
    end

    if code.include?("Streams::new()") && !code.match?(/\bfn\s+/)
      return prelude + "\n" + wrap_function(code, snippet)
    end

    if code.include?("ShiftWindows") && !code.include?("struct ShiftWindows")
      return prelude + "\n" + wrap_function(shift_windows_projection + "\n" + code, snippet)
    end

    if code.lstrip.start_with?("#[planning_solution", "#[planning_entity", "#[problem_fact")
      if code.lstrip.start_with?("#[planning_solution") && code.include?('constraints = "define_constraints"')
        return item_prelude + "\n" + code + "\n" + planning_solution_support("Schedule")
      end
      if code.include?("#[planning_solution") && code.include?("pub struct Schedule") && !code.include?("PlanningModelSupport")
        return item_prelude + "\n" + code + "\n" + planning_model_support_impl("Schedule")
      end
      return item_prelude + "\n" + code
    end

    if snippet.compile_mode == :item && !contains_top_level_let?(code)
      if code.include?("#[planning_solution") && code.include?("pub struct Plan") && !code.include?("PlanningModelSupport")
        return item_prelude + "\n" + code + "\n" + planning_model_support_impl("Plan")
      end
      if code.include?("#[planning_solution") && code.include?("pub struct Schedule") && !code.include?("PlanningModelSupport")
        return item_prelude + "\n" + code + "\n" + planning_model_support_impl("Schedule")
      end
      return item_prelude + "\n" + code
    end

    prelude + "\n" + wrap_function(code, snippet)
  end

  def render_maps(snippet)
    code = snippet.raw_code
    prelude = <<~RS
      use super::*;
      use solverforge_maps::*;
    RS
    return prelude + "\n" + code if code.include?("#[tokio::main]")

    setup = <<~RS
      let depot = Coord::try_new(39.9526, -75.1652)?;
      let customer_a = Coord::try_new(39.9610, -75.1700)?;
      let customer_b = Coord::try_new(39.9440, -75.1500)?;
      let locations = vec![depot, customer_a, customer_b];
      let bbox = BoundingBox::from_coords(&locations).expand_for_routing(&locations);
      let config = NetworkConfig::default();
      let network = RoadNetwork::new();
      let matrix = TravelTimeMatrix::default();
      let route = RouteResult { duration_seconds: 0, distance_meters: 0.0, geometry: locations.clone() };
    RS
    prelude + "\n" + wrap_async_result_function(setup + "\n" + code)
  end

  def render_ui(snippet)
    code = snippet.raw_code
    prelude = <<~RS
      use axum::{routing::get, Router};

      mod api {
          pub fn router<T>(_state: T) -> axum::Router {
              axum::Router::new()
          }
      }
    RS

    return code if code.include?("fn app()")

    prelude + "\n" + wrap_function("let state = ();\n#{code}", snippet)
  end

  def wrap_function(code, snippet)
    setup = if @profile == "solverforge-current"
              core_setup(snippet)
            else
              ""
            end
    code = with_trailing_semicolon(code)
    <<~RS
      pub fn check() {
      #{indent(setup, 8)}
      #{indent(code, 8)}
      }
    RS
  end

  def with_trailing_semicolon(code)
    stripped = code.rstrip
    return code if stripped.empty? || stripped.end_with?(";")

    "#{stripped}\n;\n"
  end

  def shift_windows_projection
    <<~RS
      struct ShiftWindows;

      impl Projection<Shift> for ShiftWindows {
          type Out = WorkWindow;
          const MAX_EMITS: usize = 2;

          fn project<Sink>(&self, shift: &Shift, sink: &mut Sink)
          where
              Sink: ProjectionSink<Self::Out>,
          {
              sink.emit(WorkWindow::primary(shift));
          }
      }
    RS
  end

  def wrap_async_result_function(code)
    <<~RS
      pub async fn check() -> solverforge_maps::RoutingResult<()> {
      #{indent(code, 8)}
          Ok(())
      }
    RS
  end

  def core_setup(snippet)
    streams_alias = if snippet.raw_code.include?("Streams::") && !snippet.raw_code.include?("type Streams")
                      if snippet.raw_code.include?("Plan::assignments()") || snippet.raw_code.include?("Plan::capacities()") || snippet.raw_code.include?(".assignments()") || snippet.raw_code.include?(".capacities()")
                        "type Streams = ConstraintFactory<Plan, HardSoftScore>;\n"
                      else
                        "type Streams = ConstraintFactory<Schedule, HardSoftScore>;\n"
                      end
                    else
                      ""
                    end
    problem_value = snippet.raw_code.include?("problem") ? "let problem = sample_schedule();\n" : ""
    manager_static = if snippet.raw_code.include?("MANAGER") && !snippet.raw_code.include?("static MANAGER")
                       "static MANAGER: SolverManager<Schedule> = SolverManager::new();\n"
                     else
                       ""
                     end
    <<~RS
      #{streams_alias}
      #{manager_static}
      let factory = ConstraintFactory::<Schedule, HardSoftScore>::new();
      let solution = sample_schedule();
      let mut solution = solution;
      #{problem_value}
    RS
  end

  def score_expression_list?(snippet)
    snippet.relpath.include?("/score-types.md") &&
      !snippet.raw_code.include?("let ")
  end

  def score_expression_lines(code)
    expression_lines(code)
  end

  def expression_lines(code)
    code.lines.map do |line|
      stripped = line.strip
      if stripped.empty? || stripped.start_with?("//") || stripped.start_with?("use ")
        line
      else
        expr, comment = line.split("//", 2)
        suffix = comment ? " //#{comment}" : ""
        "let _ = #{expr.strip};#{suffix}"
      end
    end.join
  end

  def simple_expression_list?(code)
    lines = code.lines.map(&:strip).reject(&:empty?).reject { |line| line.start_with?("//") }
    lines.size > 1 && lines.all? { |line| line.match?(/\A(?:Streams::new\(\)|factory)\./) }
  end

  def typed_stream_expression_list?(code)
    lines = code.lines.map(&:strip).reject(&:empty?).reject { |line| line.start_with?("//") }
    return false unless lines.size > 2
    return false unless lines.first.start_with?("type Streams")

    lines[1..].all? { |line| line.match?(/\A(?:Streams::new\(\)|factory)\./) }
  end

  def typed_expression_lines(code)
    code.lines.map do |line|
      stripped = line.strip
      if stripped.empty? || stripped.start_with?("//") || stripped.start_with?("type ")
        line
      else
        expr, comment = line.split("//", 2)
        suffix = comment ? " //#{comment}" : ""
        "let _ = #{expr.strip};#{suffix}"
      end
    end.join
  end

  def contains_top_level_let?(code)
    code.lines.any? { |line| line.match?(/\A\s*let\s+/) }
  end

  def indent(text, spaces)
    prefix = " " * spaces
    text.to_s.lines.map { |line| line.strip.empty? ? line : "#{prefix}#{line}" }.join
  end

  def core_fixture
    <<~RS
      use solverforge::prelude::*;
      use solverforge::stream::{joiner::*, ConstraintFactory};

      #[derive(Clone, Debug, Default, PartialEq, Eq, Hash)]
      pub struct Location;

      impl Location {
          pub fn distance_to(&self, _other: &Self) -> f64 {
              0.0
          }
      }

      #[problem_fact]
      pub struct Employee {
          #[planning_id]
          pub id: usize,
          pub index: usize,
          pub skills: Vec<String>,
          pub available_days: Vec<usize>,
      }

      #[problem_fact]
      pub struct Availability {
          #[planning_id]
          pub id: usize,
      }

      #[problem_fact]
      pub struct CustomRow {
          #[planning_id]
          pub id: usize,
      }

      #[problem_fact]
      pub struct Unavailability {
          #[planning_id]
          pub id: usize,
          pub employee_idx: Option<usize>,
          pub date: usize,
      }

      #[planning_entity]
      pub struct Shift {
          #[planning_id]
          pub id: usize,
          pub required_skill: String,
          pub date: usize,
          pub start: usize,
          pub end: usize,
          pub start_time: usize,
          pub end_time: usize,
          pub preferred: bool,
          pub hours: i64,
          pub priority: i64,
          pub department_idx: Option<usize>,
          pub location: Location,
          #[planning_variable(value_range_provider = "employees", allows_unassigned = true)]
          pub employee_idx: Option<usize>,
      }

      impl Shift {
          pub fn overlaps(&self, other: &Self) -> bool {
              self.date == other.date && self.start < other.end && other.start < self.end
          }

          pub fn is_preferred(&self) -> bool {
              self.preferred
          }

          pub fn is_preferred_by_employee(&self) -> bool {
              self.preferred
          }

          pub fn date(&self) -> usize {
              self.date
          }

          pub fn overtime_hours(&self) -> i64 {
              0
          }

          pub fn preference_penalty(&self) -> i64 {
              0
          }
      }

      #[planning_solution(constraints = "define_schedule_constraints")]
      pub struct Schedule {
          #[planning_entity_collection]
          pub shifts: Vec<Shift>,
          #[problem_fact_collection]
          pub employees: Vec<Employee>,
          #[problem_fact_collection]
          pub unavailability: Vec<Unavailability>,
          #[problem_fact_collection]
          pub custom_rows: Vec<CustomRow>,
          #[planning_score]
          pub score: Option<HardSoftScore>,
      }

      impl solverforge::__internal::PlanningModelSupport for Schedule {
          fn attach_descriptor_hooks(_descriptor: &mut solverforge::__internal::SolutionDescriptor) {}

          fn attach_runtime_scalar_hooks(
              slot: solverforge::__internal::ScalarVariableSlot<Self>,
          ) -> solverforge::__internal::ScalarVariableSlot<Self> {
              slot
          }

          fn attach_scalar_groups(
              _scalar_variables: &[solverforge::__internal::ScalarVariableSlot<Self>],
          ) -> Vec<solverforge::__internal::ScalarGroupBinding<Self>> {
              Vec::new()
          }

          fn validate_model(_descriptor: &solverforge::__internal::SolutionDescriptor) {}

          fn update_entity_shadows(
              _solution: &mut Self,
              _descriptor_index: usize,
              _entity_index: usize,
          ) -> bool {
              false
          }

          fn update_all_shadows(_solution: &mut Self) -> bool {
              false
          }
      }

      pub fn define_schedule_constraints() -> impl ConstraintSet<Schedule, HardSoftScore> {
          (
              ConstraintFactory::<Schedule, HardSoftScore>::new()
                  .for_each(Schedule::shifts())
                  .unassigned()
                  .penalize_hard()
                  .named("Unassigned shift"),
          )
      }

      pub fn sample_schedule() -> Schedule {
          Schedule {
              shifts: vec![],
              employees: vec![],
              unavailability: vec![],
              custom_rows: vec![],
              score: None,
          }
      }

      #[problem_fact]
      pub struct Capacity {
          #[planning_id]
          pub id: usize,
          pub bucket: usize,
          pub amount: i64,
      }

      #[planning_entity]
      pub struct Assignment {
          #[planning_id]
          pub id: usize,
          pub bucket: usize,
          pub capacity_id: Option<usize>,
          pub demand: i64,
      }

      pub struct AssignmentCapacity {
          pub assignment_id: usize,
          pub demand: i64,
          pub capacity: i64,
      }

      pub struct CapacityViolation {
          pub assignment_id: usize,
          pub score: HardSoftScore,
      }

      pub struct ShiftPenalty {
          pub score: HardSoftScore,
      }

      pub struct WorkWindow {
          pub shift_id: usize,
          pub employee_id: Option<usize>,
          pub start: usize,
          pub end: usize,
      }

      impl WorkWindow {
          pub fn primary(shift: &Shift) -> Self {
              Self {
                  shift_id: shift.id,
                  employee_id: shift.employee_idx,
                  start: shift.start,
                  end: shift.end,
              }
          }

          pub fn secondary(_shift: &Shift) -> Option<Self> {
              None
          }

          pub fn is_overtime(&self) -> bool {
              false
          }

          pub fn overlaps(&self, other: &Self) -> bool {
              self.start < other.end && other.start < self.end
          }
      }

      pub struct ShiftPenaltyProjection;

      impl Projection<Shift> for ShiftPenaltyProjection {
          type Out = ShiftPenalty;
          const MAX_EMITS: usize = 1;

          fn project<Sink>(&self, _shift: &Shift, sink: &mut Sink)
          where
              Sink: ProjectionSink<Self::Out>,
          {
              sink.emit(ShiftPenalty { score: HardSoftScore::ONE_HARD });
          }
      }

      #[planning_solution(constraints = "define_plan_constraints")]
      pub struct Plan {
          #[problem_fact_collection]
          pub capacities: Vec<Capacity>,
          #[planning_entity_collection]
          pub assignments: Vec<Assignment>,
          #[planning_score]
          pub score: Option<HardSoftScore>,
      }

      impl solverforge::__internal::PlanningModelSupport for Plan {
          fn attach_descriptor_hooks(_descriptor: &mut solverforge::__internal::SolutionDescriptor) {}

          fn attach_runtime_scalar_hooks(
              slot: solverforge::__internal::ScalarVariableSlot<Self>,
          ) -> solverforge::__internal::ScalarVariableSlot<Self> {
              slot
          }

          fn attach_scalar_groups(
              _scalar_variables: &[solverforge::__internal::ScalarVariableSlot<Self>],
          ) -> Vec<solverforge::__internal::ScalarGroupBinding<Self>> {
              Vec::new()
          }

          fn validate_model(_descriptor: &solverforge::__internal::SolutionDescriptor) {}

          fn update_entity_shadows(
              _solution: &mut Self,
              _descriptor_index: usize,
              _entity_index: usize,
          ) -> bool {
              false
          }

          fn update_all_shadows(_solution: &mut Self) -> bool {
              false
          }
      }

      pub fn define_plan_constraints() -> impl ConstraintSet<Plan, HardSoftScore> {
          (
              ConstraintFactory::<Plan, HardSoftScore>::new()
                  .for_each(Plan::assignments())
                  .penalize_hard()
                  .named("Assignment placeholder"),
          )
      }

      #[problem_fact]
      pub struct Visit {
          #[planning_id]
          pub id: usize,
          pub location: Location,
          pub demand: i32,
      }

      #[planning_entity]
      pub struct Vehicle {
          #[planning_id]
          pub id: usize,
          pub capacity: i32,
          pub depot: Location,
          #[planning_list_variable(element_collection = "visits")]
          pub visits: Vec<usize>,
      }

      impl Vehicle {
          pub fn total_demand(&self) -> i32 {
              0
          }

          pub fn total_distance(&self) -> i64 {
              0
          }
      }

      #[planning_solution(constraints = "define_vehicle_route_constraints")]
      pub struct VehicleRoutePlan {
          #[problem_fact_collection]
          pub visits: Vec<Visit>,
          #[planning_entity_collection]
          pub vehicles: Vec<Vehicle>,
          #[planning_score]
          pub score: Option<HardSoftScore>,
      }

      impl solverforge::__internal::PlanningModelSupport for VehicleRoutePlan {
          fn attach_descriptor_hooks(_descriptor: &mut solverforge::__internal::SolutionDescriptor) {}

          fn attach_runtime_scalar_hooks(
              slot: solverforge::__internal::ScalarVariableSlot<Self>,
          ) -> solverforge::__internal::ScalarVariableSlot<Self> {
              slot
          }

          fn attach_scalar_groups(
              _scalar_variables: &[solverforge::__internal::ScalarVariableSlot<Self>],
          ) -> Vec<solverforge::__internal::ScalarGroupBinding<Self>> {
              Vec::new()
          }

          fn validate_model(_descriptor: &solverforge::__internal::SolutionDescriptor) {}

          fn update_entity_shadows(
              _solution: &mut Self,
              _descriptor_index: usize,
              _entity_index: usize,
          ) -> bool {
              false
          }

          fn update_all_shadows(_solution: &mut Self) -> bool {
              false
          }
      }

      pub fn define_vehicle_route_constraints() -> impl ConstraintSet<VehicleRoutePlan, HardSoftScore> {
          (
              ConstraintFactory::<VehicleRoutePlan, HardSoftScore>::new()
                  .for_each(VehicleRoutePlan::vehicles())
                  .penalize_hard()
                  .named("Vehicle placeholder"),
          )
      }
    RS
  end

  def planning_solution_support(type_name)
    <<~RS

      fn define_constraints() -> impl ConstraintSet<#{type_name}, HardSoftScore> {
          (
              ConstraintFactory::<#{type_name}, HardSoftScore>::new()
                  .for_each(#{type_name}::shifts())
                  .penalize(HardSoftScore::ONE_HARD)
                  .named("snippet placeholder"),
          )
      }

      #{planning_model_support_impl(type_name)}
    RS
  end

  def planning_model_support_impl(type_name)
    <<~RS
      impl solverforge::__internal::PlanningModelSupport for #{type_name} {
          fn attach_descriptor_hooks(_descriptor: &mut solverforge::__internal::SolutionDescriptor) {}

          fn attach_runtime_scalar_hooks(
              slot: solverforge::__internal::ScalarVariableSlot<Self>,
          ) -> solverforge::__internal::ScalarVariableSlot<Self> {
              slot
          }

          fn attach_scalar_groups(
              _scalar_variables: &[solverforge::__internal::ScalarVariableSlot<Self>],
          ) -> Vec<solverforge::__internal::ScalarGroupBinding<Self>> {
              Vec::new()
          }

          fn validate_model(_descriptor: &solverforge::__internal::SolutionDescriptor) {}

          fn update_entity_shadows(
              _solution: &mut Self,
              _descriptor_index: usize,
              _entity_index: usize,
          ) -> bool {
              false
          }

          fn update_all_shadows(_solution: &mut Self) -> bool {
              false
          }
      }
    RS
  end

  def maps_fixture
    <<~RS
      use solverforge_maps::*;
    RS
  end

  def ui_fixture
    <<~RS
      use axum::Router;
    RS
  end
end

class Reporter
  def initialize(snippets)
    @snippets = snippets
  end

  def list
    @snippets.each do |snippet|
      puts format(
        "%-70s %-26s %-18s %-10s %s",
        "#{snippet.relpath}:#{snippet.line}",
        snippet.profile,
        snippet.fixture,
        snippet.status,
        snippet.reason
      )
    end
  end

  def summary
    counts = @snippets.group_by(&:status).transform_values(&:size)
    total = @snippets.size
    compiled = counts.fetch(:compile, 0)
    audited = counts.fetch(:audited, 0)
    ignored = counts.fetch(:ignored, 0)
    puts "[verify-rust-snippets] OK: #{total} Rust snippets classified; #{compiled} compiled, #{audited} audited, #{ignored} ignored"
  end
end

def parse_options(argv)
  options = {
    fail_on_unclassified: true,
    keep_temp: false,
    list: false,
    only: nil,
    verbose: false
  }

  OptionParser.new do |parser|
    parser.banner = "Usage: ruby scripts/verify-rust-snippets.rb [options]"
    parser.on("--only PATH[:LINE]", "Verify only snippets from a path, optionally near a line") { |value| options[:only] = value }
    parser.on("--verbose", "Print cargo output as it runs") { options[:verbose] = true }
    parser.on("--keep-temp", "Keep generated Cargo crates") { options[:keep_temp] = true }
    parser.on("--list", "List extracted snippets and classifications") { options[:list] = true }
    parser.on("--fail-on-unclassified", "Fail if any snippet cannot be classified") { options[:fail_on_unclassified] = true }
    parser.on("--no-fail-on-unclassified", "Allow unclassified snippets") { options[:fail_on_unclassified] = false }
  end.parse!(argv)

  options
end

def apply_only_filter(snippets, only)
  return snippets unless only

  path, line = only.split(":", 2)
  line = line&.to_i
  normalized = path.delete_prefix("./")
  snippets.select do |snippet|
    path_match = snippet.relpath == normalized || snippet.relpath.end_with?(normalized)
    next false unless path_match
    next true unless line&.positive?

    (snippet.line - 3..snippet.line + 3).cover?(line)
  end
end

def main(argv)
  options = parse_options(argv)
  snippets = Extractor.new.extract
  snippets = apply_only_filter(snippets, options[:only])
  raise VerificationError, "no Rust snippets matched --only #{options[:only]}" if snippets.empty?

  resolver = ProfileResolver.new
  snippets.each { |snippet| resolver.resolve!(snippet) }
  PolicyGate.new.check!(snippets)

  if options[:fail_on_unclassified] && snippets.any? { |snippet| snippet.status.nil? }
    raise VerificationError, "unclassified Rust snippets remain"
  end

  reporter = Reporter.new(snippets)
  if options[:list]
    reporter.list
    return
  end

  CargoWorkspaceBuilder.new(
    snippets,
    verbose: options[:verbose],
    keep_temp: options[:keep_temp]
  ).verify!

  reporter.summary
end

begin
  main(ARGV)
rescue VerificationError => e
  warn e.message
  exit 1
end
