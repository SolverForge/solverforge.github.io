#!/usr/bin/env ruby
# frozen_string_literal: true

# Writes src/_data/workbench.json from a SolverForge Workbench engine binary:
# every stock model as the engine describes it (summary, demos, data tables,
# parameters, and every constraint with its group, level and description).
# Run it against the binary of the engine release the docs describe:
#
#   ruby scripts/import-workbench.rb path/to/solverforge-workbench-x86_64-unknown-linux-musl
#
# The docs pages, the constraint search and verify-workbench.rb all read the
# file this writes, so nothing on the site restates a count by hand.
require "json"
require "open3"

module WorkbenchImport
  ROOT = File.expand_path("..", __dir__)
  OUT = File.join(ROOT, "src/_data/workbench.json")
  ORDER = %w[employee-scheduling task-scheduling pickup-delivery-routing field-service-routing].freeze

  module_function

  def ask(engine, request)
    out, err, status = Open3.capture3(engine, stdin_data: "#{JSON.generate(request)}\n")
    abort("engine failed on #{request}: #{err}") unless status.success?
    last = out.lines.map(&:strip).reject(&:empty?).last
    answer = JSON.parse(last)
    abort("engine answered #{answer["event"]}: #{answer["error"]}") if answer["event"] == "error"
    answer
  end

  def column(col)
    {
      "name" => col["name"],
      "label" => col["label"],
      "kind" => col["kind"],
      "unit" => col["unit"],
      "optional" => col["optional"] ? true : false,
      "read_only" => col["read_only"] ? true : false,
      "reference" => col["reference"],
      "options" => (col["options"] || []).map { |o| o["label"] },
      "fields" => (col["fields"] || []).map { |f| column(f) },
    }.compact
  end

  def model(engine, id)
    d = ask(engine, { "command" => "describe", "model" => id })
    {
      "id" => id,
      "name" => d.fetch("name"),
      "summary" => d.fetch("summary"),
      "view" => d["view"],
      "roads" => d["roads"] ? true : false,
      "demos" => d.fetch("demo_info").map { |demo| demo.slice("id", "name", "summary") },
      "tables" => d.fetch("tables").map do |t|
        { "id" => t["id"], "label" => t["label"], "path" => t["path"], "columns" => t["columns"].map { |c| column(c) } }
      end,
      "parameters" => d.fetch("parameters").map do |p|
        { "name" => p["name"], "label" => p["label"], "kind" => p["kind"], "unit" => p["unit"],
          "default" => p["default"], "description" => p["description"],
          "options" => (p["options"] || []).map { |o| o["label"] } }.compact
      end,
      "constraints" => d.fetch("constraints").map { |c| c.slice("name", "group", "level", "description") },
    }
  end

  def run(engine)
    abort("usage: import-workbench.rb <engine binary>") unless engine && File.executable?(engine)
    out, = Open3.capture2(engine, "--version")
    version = JSON.parse(out.lines.last).fetch("version")
    ids = JSON.parse(out.lines.last).fetch("models").map { |m| m["id"] }
    abort("engine models #{ids} are not #{ORDER}") unless ids.sort == ORDER.sort
    data = { "engine_version" => version, "models" => ORDER.map { |id| model(engine, id) } }
    File.write(OUT, "#{JSON.pretty_generate(data)}\n")
    total = data["models"].sum { |m| m["constraints"].size }
    puts "[import-workbench] engine #{version}: #{data["models"].size} models, #{total} constraints -> #{OUT}"
  end
end

WorkbenchImport.run(ARGV[0]) if $PROGRAM_NAME == __FILE__
