#!/usr/bin/env ruby
# frozen_string_literal: true

SCRIPT_DIR = File.expand_path(__dir__)
SITE_ROOT = File.expand_path("..", SCRIPT_DIR)
EXPECTED_RUNTIME_VERSION = "0.14.1"
EXPECTED_UI_VERSION = "0.6.5"
EXPECTED_CLI_VERSION = "2.0.4"

def log(message)
  puts "[verify-lessons-tutorial] #{message}"
end

def fail!(message)
  warn "[verify-lessons-tutorial] ERROR: #{message}"
  exit 1
end

def discover_repo(env_name, candidates)
  configured = ENV[env_name]

  if configured && !configured.empty?
    path = File.expand_path(configured)
    fail!("#{env_name} points to missing repo: #{configured}") unless Dir.exist?(path)

    return path
  end

  candidates.each do |candidate|
    path = File.expand_path(candidate)
    return path if Dir.exist?(path)
  end

  nil
end

def read_file(path)
  fail!("missing file: #{path}") unless File.file?(path)

  File.read(path)
end

def assert_file_contains(path, needle)
  text = read_file(path)
  fail!("#{path} is missing: #{needle}") unless text.include?(needle)
end

def assert_rendered_h1_count
  rendered_doc = File.join(SITE_ROOT, "output/docs/getting-started/solverforge-lessons-use-case/index.html")

  unless File.file?(rendered_doc)
    log "Skipping rendered H1 check; build output not found at #{rendered_doc}"
    return
  end

  count = File.read(rendered_doc).scan(/<h1(?:\s|>)/i).size
  fail!("rendered lessons tutorial should have exactly one H1, found #{count}") unless count == 1
end

doc_page = File.join(SITE_ROOT, "src/docs/getting-started/solverforge-lessons-use-case.md")
hub_page = File.join(SITE_ROOT, "src/docs/getting-started/index.md")
docs_index = File.join(SITE_ROOT, "src/docs/index.md")
docs_nav = File.join(SITE_ROOT, "src/_data/docs_nav.yml")
search_surface = File.join(SITE_ROOT, "src/_components/shared/search_surface.rb")

log "Checking public copy and tutorial anchors"
assert_file_contains(doc_page, "SolverForge Lessons Use Case")
assert_file_contains(doc_page, "https://huggingface.co/spaces/SolverForge/solverforge-lessons")
assert_file_contains(doc_page, "solverforge #{EXPECTED_RUNTIME_VERSION}")
assert_file_contains(doc_page, "solverforge-ui #{EXPECTED_UI_VERSION}")
assert_file_contains(doc_page, "solverforge-cli #{EXPECTED_CLI_VERSION}")
assert_file_contains(doc_page, "tokio = { version = \"1.52.1\", features = [\"full\"] }")
assert_file_contains(doc_page, "tower-http = { version = \"0.6.8\", features = [\"fs\", \"cors\"] }")
assert_file_contains(doc_page, "HardMediumSoftScore")
assert_file_contains(doc_page, "300 lessons")
assert_file_contains(doc_page, "40 weekly timeslots")
assert_file_contains(doc_page, "10 typed rooms")
assert_file_contains(doc_page, "assign_timeslot")
assert_file_contains(doc_page, "repeated_subject_day")
assert_file_contains(doc_page, "make test-slow")
assert_file_contains(hub_page, "SolverForge Lessons Use Case")
assert_file_contains(docs_index, "Lessons Use Case")
assert_file_contains(docs_nav, "/docs/getting-started/solverforge-lessons-use-case/")
assert_file_contains(search_surface, "SolverForge Lessons Use Case")

usecases_repo = discover_repo("SOLVERFORGE_USECASES_REPO", [
  File.join(Dir.home, "dev/solverforge/solverforge-usecases"),
  "/srv/lab/dev/solverforge/solverforge-usecases",
  File.join(SITE_ROOT, "../solverforge-usecases"),
  File.join(SITE_ROOT, "../../solverforge-usecases")
])

if usecases_repo
  log "Using use-case bundle repo: #{usecases_repo}"
  lessons_root = File.join(usecases_repo, "uc-lessons")
  assert_file_contains(File.join(lessons_root, "Cargo.toml"), "solverforge = { version = \"#{EXPECTED_RUNTIME_VERSION}\"")
  assert_file_contains(File.join(lessons_root, "Cargo.toml"), "solverforge-ui = { version = \"#{EXPECTED_UI_VERSION}\"")
  assert_file_contains(File.join(lessons_root, "Cargo.toml"), "tokio = { version = \"1.52.1\", features = [\"full\"] }")
  assert_file_contains(File.join(lessons_root, "Cargo.toml"), "tower-http = { version = \"0.6.8\", features = [\"fs\", \"cors\"] }")
  assert_file_contains(File.join(lessons_root, "solverforge.app.toml"), "cli_version = \"#{EXPECTED_CLI_VERSION}\"")
  assert_file_contains(File.join(lessons_root, "solverforge.app.toml"), "score = \"HardMediumSoftScore\"")
  assert_file_contains(File.join(lessons_root, "solver.toml"), "construction_heuristic_type = \"cheapest_insertion\"")
  assert_file_contains(File.join(lessons_root, "src/data/data_seed/vocabulary.rs"), "TIMESLOT_COUNT: usize = 40")
  assert_file_contains(File.join(lessons_root, "src/data/data_seed/vocabulary.rs"), "GROUP_COUNT: usize = 12")
  assert_file_contains(File.join(lessons_root, "src/data/data_seed/vocabulary.rs"), "ROOM_COUNT: usize = 10")
  assert_file_contains(File.join(lessons_root, "src/domain/lesson.rs"), "pub timeslot_idx: Option<usize>")
  assert_file_contains(File.join(lessons_root, "src/domain/lesson.rs"), "pub room_idx: Option<usize>")
else
  log "Skipping bundle metadata checks; set SOLVERFORGE_USECASES_REPO to enable them."
end

assert_rendered_h1_count
log "Lessons tutorial contract checks passed"
