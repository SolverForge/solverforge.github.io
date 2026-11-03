#!/usr/bin/env ruby
# frozen_string_literal: true

# Holds the Deliveries use-case page to what its reader gets.
#
#   ruby scripts/verify-deliveries-tutorial.rb            # static + live replay
#   ruby scripts/verify-deliveries-tutorial.rb --static   # page contract only
#
# The live replay installs solverforge-cli at CLI_VERSION, builds and solves
# the page's CLI router, clones the Hugging Face Space the page names,
# solves it, compares the page's claims with the clone, and runs the page's
# validation commands there (see scripts/lib/use_case_tutorial.rb).
#
# Solving the finished app downloads road data from the Overpass API on a
# cache miss; TUTORIAL_REPLAY_OSM_CACHE keeps `.osm_cache` between runs.

require_relative "lib/use_case_tutorial"

SITE_ROOT = File.expand_path("..", __dir__)
CLI_VERSION = "3.8.2"

def site_file(path)
  File.join(SITE_ROOT, path)
end

navigation = lambda do |_text, gate|
  {
    "src/docs/getting-started/index.md" => "SolverForge Deliveries Use Case",
    "src/docs/index.md" => "Deliveries Use Case",
    "src/_data/docs_nav.yml" => "/docs/getting-started/solverforge-deliveries-use-case/",
    "src/_components/shared/search_surface.rb" => "SolverForge Deliveries Use Case"
  }.each do |path, needle|
    gate.fail!("#{path} no longer links the deliveries page (#{needle})") unless File.read(site_file(path)).include?(needle)
  end
end

UseCaseTutorial.run(
  UseCaseTutorial::Config.new(
    name: "verify-deliveries-tutorial",
    page: site_file("src/docs/getting-started/solverforge-deliveries-use-case.md"),
    page_url: "docs/getting-started/solverforge-deliveries-use-case",
    cli_version: CLI_VERSION,
    runtime_version: "0.24.0",
    space_url: "https://huggingface.co/spaces/SolverForge/solverforge-deliveries",
    app: "deliveries",
    cli_section: "Build a Router from the CLI",
    clone_section: "Run the Finished Example",
    constraints_section: "Writing Constraints",
    validation_section: "Testing and Validation",
    not_run: {
      "make ci-local" => "needs Docker",
      "make space-build" => "needs Docker",
      "make space-run" => "needs Docker and runs until stopped",
      "make test-live-road" => "always fetches fresh road data from the public Overpass API"
    },
    dataset_table: {
      "Vehicles" => UseCaseTutorial.count("vehicles"),
      "Deliveries" => UseCaseTutorial.count("deliveries")
    },
    cli_score_prefix: "0hard",
    banned: {
      "straight_line" => "the app accepts only road_network routing (POST /jobs answers 400)",
      "It is runnable" => "the neutral scaffold solves nothing until the page's code is in"
    },
    osm_cache: true,
    extra_static: navigation
  )
)
