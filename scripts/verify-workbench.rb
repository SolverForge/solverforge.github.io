#!/usr/bin/env ruby
# frozen_string_literal: true

# The SolverForge Workbench docs against the engine data they render
# (src/_data/workbench.json, written by import-workbench.rb):
#
# - the data holds the four stock models, each constraint with a name unique
#   in its model, a group, a level and a one-sentence description;
# - every model has its overview, data and constraints pages, and the
#   constraints page explains every constraint the engine scores, exactly once,
#   under its own group, with what it reads, costs, an example and its weight;
# - the docs nav links the overview and each model's three pages;
# - the Workbench product case states the same constraint counts.
#
# With --engine BIN it also describes every model with that engine binary and
# requires the data to match it exactly, so the pages cannot drift from the
# release they name.
require "json"
require "yaml"
require "open3"

module VerifyWorkbench
  ROOT = File.expand_path("..", __dir__)
  DATA = File.join(ROOT, "src/_data/workbench.json")
  MODELS = %w[employee-scheduling task-scheduling pickup-delivery-routing field-service-routing].freeze
  LEVELS = %w[hard medium soft].freeze
  NAMES = {
    "employee-scheduling" => "Employee scheduling",
    "task-scheduling" => "Task scheduling",
    "pickup-delivery-routing" => "Pick-up and delivery routing",
    "field-service-routing" => "Field service routing",
  }.freeze

  module_function

  def run(argv)
    failures = []
    data = JSON.parse(File.read(DATA))
    models = data.fetch("models")
    failures << "engine_version missing" unless data["engine_version"].to_s.match?(/\A\d+\.\d+\.\d+\z/)
    failures << "models are #{models.map { |m| m["id"] }}, not #{MODELS}" unless models.map { |m| m["id"] } == MODELS
    models.each { |model| failures.concat(check_model(model)) }
    failures.concat(check_pages(models))
    failures.concat(check_product(models))
    engine = argv.index("--engine") && argv[argv.index("--engine") + 1]
    failures.concat(check_engine(engine, data)) if engine
    total = models.sum { |m| m["constraints"].size }
    if failures.empty?
      puts "[verify-workbench] OK: engine #{data["engine_version"]}, #{models.size} models, #{total} constraints#{engine ? ", matching #{engine}" : ""}"
    else
      failures.each { |f| warn "[verify-workbench] #{f}" }
      exit 1
    end
  end

  def check_model(model)
    id = model["id"]
    failures = []
    rules = model.fetch("constraints")
    failures << "#{id}: no constraints" if rules.empty?
    duplicates = rules.map { |r| r["name"] }.tally.select { |_, n| n > 1 }.keys
    failures << "#{id}: duplicate constraint names #{duplicates}" unless duplicates.empty?
    rules.each do |rule|
      failures << "#{id}: #{rule["name"].inspect} has level #{rule["level"].inspect}" unless LEVELS.include?(rule["level"])
      failures << "#{id}: #{rule["name"].inspect} has no group" if rule["group"].to_s.strip.empty?
      failures << "#{id}: #{rule["name"].inspect} description is not a sentence" unless rule["description"].to_s.end_with?(".")
    end
    failures << "#{id}: no data tables" if model.fetch("tables").empty?
    failures << "#{id}: no demo" if model.fetch("demos").empty?
    failures << "#{id}: named #{model["name"].inspect}" unless model["name"] == NAMES[id]
    failures
  end

  PART = %w[Reads Cost Example Weight].freeze

  def check_pages(models)
    failures = []
    dir = File.join(ROOT, "src/docs/solverforge-workbench")
    models.each do |model|
      id = model["id"]
      {
        "index.md" => %(Workbench::Groups.new(site: site, model: "#{id}")),
        "data.md" => %(Workbench::DataReference.new(site: site, model: "#{id}")),
        "constraints.md" => %(<% m = "#{id}" %>),
      }.each do |file, mark|
        path = File.join(dir, id, file)
        next failures << "missing page #{id}/#{file}" unless File.file?(path)
        failures << "#{id}/#{file} does not render its model" unless File.read(path).include?(mark)
      end
      path = File.join(dir, id, "constraints.md")
      failures.concat(check_explanations(model, File.read(path))) if File.file?(path)
    end
    nav = YAML.safe_load_file(File.join(ROOT, "src/_data/docs_nav.yml"))
    section = nav.fetch("docs").find { |item| item["href"] == "/docs/solverforge-workbench/" }
    if section
      children = Array(section["children"])
      hrefs = children.map { |c| c["href"] }
      expected = MODELS.map { |id| "/docs/solverforge-workbench/#{id}/" }
      failures << "docs nav lists #{hrefs}, not #{expected}" unless hrefs == expected
      children.each do |child|
        pages = Array(child["children"]).map { |c| c["href"] }
        want = %w[constraints data].map { |p| "#{child["href"]}#{p}/" }
        failures << "docs nav under #{child["href"]} lists #{pages}, not #{want}" unless pages == want
      end
    else
      failures << "docs nav has no SolverForge Workbench section"
    end
    failures
  end

  # Each constraint of the engine appears once on the model's constraints
  # page, under the heading of its own group, followed by an explanation with
  # every part; nothing else is explained there.
  def check_explanations(model, text)
    id = model["id"]
    failures = []
    group = nil
    seen = Hash.new(0)
    sections = text.split(/^(?=## |<%= render Workbench::Rule\.new)/)
    sections.each do |part|
      if (heading = part[/\A## (.+?) \{#group-[a-z0-9-]+\}/, 1])
        group = heading
        next
      end
      name = part[/\A<%= render Workbench::Rule\.new\(site: site, model: m, name: "([^"]+)"\) %>/, 1]
      next unless name
      seen[name] += 1
      rule = model["constraints"].find { |r| r["name"] == name }
      next failures << "#{id}: explains #{name.inspect}, which the engine does not score" unless rule
      failures << "#{id}: #{name.inspect} sits under #{group.inspect}, its group is #{rule["group"].inspect}" unless group == rule["group"]
      PART.each do |label|
        failures << "#{id}: #{name.inspect} has no **#{label}:** line" unless part.include?("**#{label}:**")
      end
      intro = part.lines.drop(1).take_while { |l| !l.start_with?("- **") }.join.strip
      failures << "#{id}: #{name.inspect} has no explanation before its details" if intro.length < 40
    end
    model["constraints"].each do |rule|
      n = seen[rule["name"]]
      failures << "#{id}: #{rule["name"].inspect} is explained #{n} times" unless n == 1
    end
    failures
  end

  def check_product(models)
    failures = []
    cases = YAML.safe_load_file(File.join(ROOT, "src/_data/use_cases.yml"))
    product = cases.find { |c| c["id"] == "hermes-workbench" }
    return ["no hermes-workbench case"] unless product
    total = models.sum { |m| m["constraints"].size }
    failures << "teaser says #{product["teaser_metric"].inspect}, not #{total} constraints" unless product["teaser_metric"].include?("#{total} constraints")
    metric = product["metrics"].find { |_, label| label == "Constraints" }
    failures << "metrics say #{metric&.first.inspect} constraints, not #{total}" unless metric && metric.first == total.to_s
    models.each do |model|
      row = product["constraints"].find { |name, _| name == model["name"] }
      count = model["constraints"].size
      failures << "#{model["name"]}: product row #{row&.last.inspect} does not start with #{count} constraints" unless row && row.last.start_with?("#{count} constraints")
    end
    failures
  end

  def check_engine(engine, data)
    out, status = Open3.capture2(engine, "--version")
    return ["#{engine} --version failed"] unless status.success?
    version = JSON.parse(out.lines.last)["version"]
    failures = []
    failures << "data names engine #{data["engine_version"]}, the binary is #{version}" unless version == data["engine_version"]
    data["models"].each do |model|
      answer, = Open3.capture2(engine, stdin_data: %({"command":"describe","model":"#{model["id"]}"}\n))
      described = JSON.parse(answer.lines.map(&:strip).reject(&:empty?).last)
      live = described.fetch("constraints").map { |c| c.slice("name", "group", "level", "description") }
      failures << "#{model["id"]}: constraints differ from #{engine}" unless live == model["constraints"]
      failures << "#{model["id"]}: tables differ from #{engine}" unless described.fetch("tables").map { |t| t["id"] } == model["tables"].map { |t| t["id"] }
    end
    failures
  end
end

VerifyWorkbench.run(ARGV) if $PROGRAM_NAME == __FILE__
