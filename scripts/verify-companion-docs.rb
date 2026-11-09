#!/usr/bin/env ruby
# frozen_string_literal: true

# Holds the solverforge-maps, solverforge-bench, and integration-boundary pages
# to the published artifacts they describe.
#
# - solverforge-maps: the tracked version is the crates.io release, and the
#   Overpass endpoint and cache directory the pages name are the defaults in
#   that release's `NetworkConfig`.
# - solverforge-ui: the tracked version is the crates.io release.
# - Integration Boundaries: the crate that ships the OpenStreetMap tile layer
#   is the only one said to own tiles, and the page carries no version numbers
#   (versions live on each product's docs page, where gates check them).
# - solverforge-bench: every benchmark family in the repository has its table
#   row, validate/quick/canonical `make` targets, and harness path on the page;
#   every `make` target, harness option, and warehouse view the page names
#   exists; the page names the public `publishable_*` views; and every tool the
#   Makefile shells out to is listed under Prerequisites.
#
# Sources: crates.io release tarballs, and the solverforge-bench repository at
# BENCH_REF (SOLVERFORGE_BENCH_REPO when CI checks it out, otherwise a cached
# clone). Nothing here skips: a source that cannot be read is a failure.
#
#   ruby scripts/verify-companion-docs.rb

require "fileutils"
require "json"
require "net/http"
require "open3"
require "set"
require "uri"

SITE_ROOT = File.expand_path("..", __dir__)
MAPS_DOCS = File.join(SITE_ROOT, "src/docs/solverforge-maps")
UI_INDEX = File.join(SITE_ROOT, "src/docs/solverforge-ui/index.md")
BOUNDARIES = File.join(SITE_ROOT, "src/reference/integration-surfaces.md")
BENCH_PAGE = File.join(SITE_ROOT, "src/docs/solverforge-bench/index.md")
BENCH_URL = "https://github.com/SolverForge/solverforge-bench"
# The documented solverforge-bench revision. Move it with the page.
BENCH_REF = "712a30205590f8aad81ce42bf360a281cd152f0f"
CACHE = ENV.fetch("SOLVERFORGE_SITE_CACHE", File.join(Dir.home, ".cache", "solverforge-site"))
USER_AGENT = "solverforge.org docs gate (https://solverforge.org)"

# Tools a bench Makefile recipe can shell out to, keyed by the recipe text
# that proves it does.
BENCH_TOOLS = {
  "python3.14" => /^HOST_PYTHON \?= python3\.14$/,
  "maturin" => /\bmaturin build\b/,
  "sqlx" => /^SQLX \?= sqlx$/,
  "psql" => /^\tpsql /,
  "mvn" => /\bmvn -f\b/,
  "cmake" => /\bcmake -S\b/,
  "taskset" => /\btaskset -c\b/,
  "cargo" => /\bcargo build --release\b/,
  "curl" => /^\tcurl /,
  "git" => /^\tgit clone /
}.freeze

def log(message)
  puts "[verify-companion-docs] #{message}"
end

def fail!(message)
  warn "[verify-companion-docs] ERROR: #{message}"
  exit 1
end

def rel(path)
  path.delete_prefix("#{SITE_ROOT}/")
end

def read(path)
  fail!("missing file: #{rel(path)}") unless File.file?(path)
  File.read(path)
end

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

def table_rows(text)
  text.lines.map(&:strip).select { |line| line.start_with?("|") }.drop(2).map do |line|
    line.split("|").map(&:strip).reject(&:empty?)
  end
end

def get(url)
  uri = URI(url)
  response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https", open_timeout: 15, read_timeout: 60) do |http|
    http.request(Net::HTTP::Get.new(uri, "user-agent" => USER_AGENT))
  end
  return get(response["location"]) if response.is_a?(Net::HTTPRedirection)
  fail!("GET #{url} returned #{response.code}") unless response.is_a?(Net::HTTPSuccess)

  response.body
rescue StandardError => e
  fail!("could not read #{url}: #{e.message}")
end

def crates_io_latest(name)
  JSON.parse(get("https://crates.io/api/v1/crates/#{name}")).dig("crate", "max_stable_version")
end

def crate_source(name, version)
  dir = File.join(CACHE, "crates", "#{name}-#{version}")
  return dir if File.directory?(dir)

  FileUtils.mkdir_p(File.dirname(dir))
  archive = "#{dir}.crate"
  File.binwrite(archive, get("https://static.crates.io/crates/#{name}/#{name}-#{version}.crate"))
  _out, status = Open3.capture2e("tar", "-xzf", archive, "-C", File.dirname(dir))
  fail!("could not unpack #{archive}") unless status.success? && File.directory?(dir)
  dir
end

def bench_repo
  repo = ENV["SOLVERFORGE_BENCH_REPO"]
  unless repo
    repo = File.join(CACHE, "solverforge-bench")
    unless File.directory?(File.join(repo, ".git"))
      _out, status = Open3.capture2e("git", "clone", "--quiet", BENCH_URL, repo)
      fail!("could not clone #{BENCH_URL}") unless status.success?
    end
    _out, status = Open3.capture2e("git", "-C", repo, "cat-file", "-e", "#{BENCH_REF}^{commit}")
    unless status.success?
      _out, status = Open3.capture2e("git", "-C", repo, "fetch", "--quiet", "origin")
      fail!("could not fetch #{BENCH_URL}") unless status.success?
    end
    _out, status = Open3.capture2e("git", "-C", repo, "checkout", "--quiet", "--detach", BENCH_REF)
    fail!("could not check out solverforge-bench #{BENCH_REF}") unless status.success?
  end
  head, status = Open3.capture2("git", "-C", repo, "rev-parse", "HEAD")
  fail!("#{repo} is not a git checkout") unless status.success?
  fail!("solverforge-bench checkout is at #{head.strip}, the page documents #{BENCH_REF}") unless head.strip == BENCH_REF
  repo
end

def check_tracked_version(page, crate, phrase)
  latest = crates_io_latest(crate)
  stated = read(page)[/#{Regexp.escape(phrase)} `#{Regexp.escape(crate)} ([0-9][0-9.]*)`/, 1] ||
           fail!("#{rel(page)} does not state the #{crate} release it tracks")
  fail!("#{rel(page)} tracks #{crate} #{stated}, crates.io publishes #{latest}") unless stated == latest
  latest
end

def check_maps
  version = check_tracked_version(File.join(MAPS_DOCS, "index.md"), "solverforge-maps", "This section tracks the published")
  config = read(File.join(crate_source("solverforge-maps", version), "src/routing/config.rs"))
  endpoint = config[/let default_overpass = "([^"]+)"/, 1] || fail!("no default Overpass endpoint in solverforge-maps #{version}")
  cache_dir = config[/cache_dir: PathBuf::from\("([^"]+)"\)/, 1] || fail!("no default cache_dir in solverforge-maps #{version}")
  retries = config[/overpass_max_retries: (\d+),/, 1] || fail!("no default Overpass retry count in solverforge-maps #{version}")
  page = read(File.join(MAPS_DOCS, "getting-started.md"))
  fail!("maps Getting Started does not name the default Overpass endpoint #{endpoint}") unless page.include?("`#{endpoint}`")
  fail!("maps Getting Started does not name the default cache directory #{cache_dir}") unless page.include?("`#{cache_dir}`")
  fail!("maps Getting Started does not state the #{retries} default Overpass retries") unless page.match?(/retr\w*.{0,40}`#{retries}`/m)
  page.scan(/NetworkConfig::default\(\)((?:\s*\.[a-z_]+\()+)/m).flatten.join.scan(/\.([a-z_]+)\(/).flatten.uniq.each do |method|
    fail!("maps Getting Started calls NetworkConfig::#{method}, which solverforge-maps #{version} does not define") unless config.include?("pub fn #{method}(")
  end
  log "solverforge-maps #{version}: Overpass endpoint, cache directory, and retries match the crate"
  version
end

def check_boundaries(ui_version, maps_version)
  text = read(BOUNDARIES)
  versions = text.scan(/\b\d+\.\d+\.\d+\b/).uniq
  fail!("#{rel(BOUNDARIES)} states versions #{versions.join(', ')}; versions belong on each product's docs page") unless versions.empty?

  sources = {
    "solverforge-ui" => Dir.glob(File.join(crate_source("solverforge-ui", ui_version), "static/**/*.js")),
    "solverforge-maps" => Dir.glob(File.join(crate_source("solverforge-maps", maps_version), "src/**/*.rs"))
  }
  tile_owner = sources.select { |_crate, files| files.any? { |file| File.read(file).include?("tile.openstreetmap.org") } }.keys
  fail!("expected exactly one crate to ship the OpenStreetMap tile layer, found #{tile_owner}") unless tile_owner.size == 1

  rows = table_rows(section(text, "## Boundary map", BOUNDARIES)).to_h { |row| [row[0].delete("`"), row[1].to_s] }
  sources.each_key do |crate|
    owns = rows[crate] || fail!("Boundary map has no #{crate} row")
    if tile_owner.include?(crate)
      fail!("Boundary map: #{crate} ships the OpenStreetMap tile layer but its row does not say so") unless owns.match?(/tile/i)
    elsif owns.match?(/tile/i)
      fail!("Boundary map: #{crate} is said to own tiles, but the tile layer ships in #{tile_owner.first}")
    end
  end
  log "Integration Boundaries: tiles belong to #{tile_owner.first}; no version numbers"
end

def makefile_targets(makefile)
  makefile.scan(/^([a-z][a-z0-9-]*):/).flatten.to_set
end

def check_bench
  repo = bench_repo
  page = read(BENCH_PAGE)
  makefile = read(File.join(repo, "Makefile"))
  targets = makefile_targets(makefile)

  families = %w[list-variable scalar-variable].flat_map do |kind|
    Dir.children(File.join(repo, kind)).select { |name| File.directory?(File.join(repo, kind, name)) }.map { |name| "#{kind}/#{name}" }
  end.sort
  fail!("found no benchmark families in solverforge-bench") if families.empty?
  table = table_rows(section(page, "## Benchmark Families", BENCH_PAGE)).map { |row| row[1].delete("`").delete_suffix("/") }
  fail!("Benchmark Families table #{table.sort} does not match the repository #{families}") unless table.sort == families

  named_targets = page.scan(/\bmake ([a-z][a-z0-9-]*)/).flatten.to_set
  unknown = named_targets.reject { |target| targets.include?(target) }
  fail!("page names make targets that solverforge-bench does not define: #{unknown.to_a.sort.join(', ')}") unless unknown.empty?
  families.each do |family|
    name = File.basename(family)
    %W[validate-#{name} bench-#{name}-quick bench-#{name}].select { |target| targets.include?(target) }.each do |target|
      fail!("page omits `make #{target}` for #{family}") unless named_targets.include?(target)
    end
  end

  harness = section(page, "## Unified Harness", BENCH_PAGE)
  families.each do |family|
    fail!("Unified Harness PYTHONPATH omits #{family}/src") unless harness.include?("#{family}/src")
    fail!("Unified Harness has no run for #{File.basename(family)}") unless harness.include?("run_benchmark.py #{File.basename(family)}")
  end
  harness_source = Dir.glob(File.join(repo, "{src,scripts}/**/*.py")).map { |path| File.read(path) }.join
  harness.scan(/^(--[a-z][a-z-]*)/).flatten.uniq.each do |option|
    fail!("Unified Harness lists #{option}, which the harness source never defines") unless harness_source.include?(%("#{option}"))
  end

  migrations = Dir.glob(File.join(repo, "migrations/*.sql")).map { |path| File.read(path) }.join
  views = migrations.scan(/CREATE (?:OR REPLACE )?VIEW ([a-z_]+)/).flatten.to_set
  relations = views | migrations.scan(/CREATE TABLE (?:IF NOT EXISTS )?([a-z_]+)/).flatten.to_set
  page.scan(/`((?:latest_|publishable_)?benchmark_[a-z_]+)`/).flatten.uniq.each do |name|
    fail!("page names `#{name}`, which no solverforge-bench migration creates") unless relations.include?(name)
  end
  views.select { |view| view.start_with?("publishable_") }.each do |view|
    fail!("page does not name the public view `#{view}`") unless page.include?("`#{view}`")
  end

  prerequisites = section(page, "## Prerequisites", BENCH_PAGE)
  BENCH_TOOLS.each do |tool, evidence|
    next unless makefile.match?(evidence)

    fail!("Prerequisites omits `#{tool}`, which the Makefile runs") unless prerequisites.include?("`#{tool}`")
  end
  log "solverforge-bench #{BENCH_REF[0, 7]}: #{families.size} families, #{named_targets.size} make targets, views, and prerequisites match"
end

maps_version = check_maps
ui_version = check_tracked_version(UI_INDEX, "solverforge-ui", "This section tracks the published")
log "solverforge-ui index tracks the crates.io release #{ui_version}"
check_boundaries(ui_version, maps_version)
check_bench
log "OK"
