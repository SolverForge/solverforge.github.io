#!/usr/bin/env ruby
# frozen_string_literal: true

# Holds the FSR use-case page to what its reader gets.
#
#   ruby scripts/verify-fsr-tutorial.rb            # static + live replay
#   ruby scripts/verify-fsr-tutorial.rb --static   # page contract only
#
# The live replay installs solverforge-cli at CLI_VERSION, builds and solves
# the page's CLI dispatcher, clones the Hugging Face Space the page names,
# solves it, compares the page's claims with the clone, and runs the page's
# validation commands there (see scripts/lib/use_case_tutorial.rb).
#
# Solving the finished app downloads the Bergamo road graph from the Overpass
# API on a cache miss; TUTORIAL_REPLAY_OSM_CACHE keeps `.osm_cache` between runs.

require_relative "lib/use_case_tutorial"

SITE_ROOT = File.expand_path("..", __dir__)
CLI_VERSION = "4.0.2"

def site_file(path)
  File.join(SITE_ROOT, path)
end

navigation = lambda do |_text, gate|
  {
    "src/docs/getting-started/index.md" => "SolverForge FSR Use Case",
    "src/docs/index.md" => "FSR Use Case",
    "src/_data/docs_nav.yml" => "/docs/getting-started/solverforge-fsr-use-case/",
    "src/_components/shared/search_surface.rb" => "SolverForge FSR Use Case"
  }.each do |path, needle|
    gate.fail!("#{path} no longer links the fsr page (#{needle})") unless File.read(site_file(path)).include?(needle)
  end
end

UseCaseTutorial.run(
  UseCaseTutorial::Config.new(
    name: "verify-fsr-tutorial",
    page: site_file("src/docs/getting-started/solverforge-fsr-use-case.md"),
    page_url: "docs/getting-started/solverforge-fsr-use-case",
    cli_version: CLI_VERSION,
    runtime_version: "0.26.0",
    space_url: "https://huggingface.co/spaces/SolverForge/solverforge-fsr",
    app: "fsr",
    cli_section: "Build a Dispatcher from the CLI",
    clone_section: "Run the Finished Example",
    constraints_section: "Writing Constraints",
    validation_section: "Testing and Validation",
    not_run: {
      "make ci-local" => "needs Docker",
      "make space-build" => "needs Docker",
      "make space-run" => "needs Docker and runs until stopped"
    },
    dataset_table: {
      "Technicians" => UseCaseTutorial.count("technicianRoutes", "technician_routes"),
      "Service Visits" => UseCaseTutorial.count("serviceVisits", "service_visits"),
      "Locations" => UseCaseTutorial.count("locations")
    },
    cli_score_prefix: "0hard",
    banned: {
      "It is runnable" => "the neutral scaffold solves nothing until the page's code is in"
    },
    osm_cache: true,
    extra_static: navigation
  )
)
