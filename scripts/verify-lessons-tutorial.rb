#!/usr/bin/env ruby
# frozen_string_literal: true

# Holds the Lessons use-case page to what its reader gets.
#
#   ruby scripts/verify-lessons-tutorial.rb            # static + live replay
#   ruby scripts/verify-lessons-tutorial.rb --static   # page contract only
#
# The live replay installs solverforge-cli at CLI_VERSION, builds and solves
# the page's CLI timetable, clones the Hugging Face Space the page names,
# solves it, compares the page's claims with the clone, and runs the page's
# validation commands there (see scripts/lib/use_case_tutorial.rb).

require_relative "lib/use_case_tutorial"

SITE_ROOT = File.expand_path("..", __dir__)
CLI_VERSION = "4.0.4"

def site_file(path)
  File.join(SITE_ROOT, path)
end

navigation = lambda do |_text, gate|
  {
    "src/docs/getting-started/index.md" => "SolverForge Lessons Use Case",
    "src/docs/index.md" => "Lessons Use Case",
    "src/_data/docs_nav.yml" => "/docs/getting-started/solverforge-lessons-use-case/",
    "src/_components/shared/search_surface.rb" => "SolverForge Lessons Use Case"
  }.each do |path, needle|
    gate.fail!("#{path} no longer links the lessons page (#{needle})") unless File.read(site_file(path)).include?(needle)
  end
end

UseCaseTutorial.run(
  UseCaseTutorial::Config.new(
    name: "verify-lessons-tutorial",
    page: site_file("src/docs/getting-started/solverforge-lessons-use-case.md"),
    page_url: "docs/getting-started/solverforge-lessons-use-case",
    cli_version: CLI_VERSION,
    runtime_version: "0.26.1",
    space_url: "https://huggingface.co/spaces/SolverForge/solverforge-lessons",
    app: "lessons",
    cli_section: "Build a Timetable from the CLI",
    clone_section: "Run the Finished Example",
    constraints_section: "Writing Constraints",
    validation_section: "Testing and Validation",
    not_run: {
      "make ci-local" => "needs Docker",
      "make space-build" => "needs Docker",
      "make space-run" => "needs Docker and runs until stopped"
    },
    dataset_table: {
      "Lessons" => UseCaseTutorial.count("lessons"),
      "Groups" => UseCaseTutorial.count("groups"),
      "Timeslots" => UseCaseTutorial.count("timeslots"),
      "Rooms" => UseCaseTutorial.count("rooms")
    },
    cli_score_prefix: "0hard",
    banned: {
      "It is runnable" => "the neutral scaffold solves nothing until the page's code is in"
    },
    osm_cache: false,
    extra_static: navigation
  )
)
