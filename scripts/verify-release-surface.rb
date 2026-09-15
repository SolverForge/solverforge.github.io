#!/usr/bin/env ruby
# frozen_string_literal: true

ROOT = File.expand_path("..", __dir__)

REQUIRED_TEXT = {
  "src/docs/solverforge/index.md" => [
    "solverforge 0.19.4",
    "solverforge-cli 2.2.3",
    "solverforge 0.19.3",
    "docs.rs/solverforge/0.19.4/solverforge/"
  ],
  "src/docs/solverforge-python/index.md" => [
    "solverforge-py 0.6.6",
    "solverforge==0.6.6",
    "solverforge 0.19.4",
    "solverforge-ui 0.7.0"
  ],
  "src/docs/solverforge-python/modeling.md" => [
    "`candidate_values` is also the native hard domain",
    "`same_value_conflict_field`"
  ],
  "src/docs/solverforge-cli/command-reference.md" => [
    "solverforge-cli 2.2.3",
    "SolverForge crate target 0.19.3",
    "solverforge-ui 0.7.0"
  ],
  "src/docs/solverforge-ui/index.md" => [
    "solverforge-ui 0.8.0",
    "solverforge-cli 2.2.3",
    "solverforge-ui 0.7.0",
    "/sf/sf.0.8.0.css",
    "SF.version"
  ],
  "src/docs/solverforge-ui/integration-assets.md" => [
    "solverforge-ui 0.8.0",
    "solverforge_ui::assets::version()",
    "SF.version",
    "onFailure",
    "onCancelled"
  ],
  "src/docs/solverforge-ui/components.md" => [
    "content: { unsafeHtml:",
    "tabs[].content.unsafeHtml"
  ],
  "src/docs/solverforge-ui/scheduling-views.md" => [
    "isWeekend",
    "non-zero layout dimensions",
    "unsafePopupHtml"
  ],
  "src/reference/lifecycle-pause-resume-contract.md" => [
    "solverforge-ui 0.8.0"
  ],
  "src/_posts/releases/2026-09-15-solverforge-ui-0-8-x.md" => [
    "`0.8.0` | 2026-09-15",
    "SF.version",
    "solverforge_ui::assets::version()"
  ],
  "src/docs/status-and-roadmap.md" => [
    "solverforge 0.19.4",
    "solverforge-py 0.6.6",
    "solverforge-cli 2.2.3",
    "solverforge-ui 0.8.0",
    "solverforge-hospital@2.0.7",
    "solverforge-lessons@2.0.7",
    "solverforge-deliveries@2.0.7",
    "solverforge-fsr@2.0.8"
  ],
  "src/docs/getting-started/solverforge-hospital-use-case.md" => [
    "solverforge-hospital@2.0.7",
    "solverforge 0.19.4"
  ],
  "src/docs/getting-started/solverforge-lessons-use-case.md" => [
    "solverforge-lessons@2.0.7",
    "solverforge 0.19.4"
  ],
  "src/docs/getting-started/solverforge-deliveries-use-case.md" => [
    "solverforge-deliveries@2.0.7",
    "solverforge 0.19.4"
  ],
  "src/docs/getting-started/solverforge-fsr-use-case.md" => [
    "solverforge-fsr@2.0.8",
    "solverforge 0.19.4"
  ],
  "src/_posts/releases/2026-07-17-solverforge-0-19-x.md" => [
    "`0.19.4` | 2026-08-11",
    "`0.19.3` | 2026-07-29",
    "`0.19.2` | 2026-07-19",
    "solverforge-hospital@2.0.7"
  ],
  "src/_posts/releases/2026-07-13-solverforge-python-0-6-x.md" => [
    "`0.6.6` | 2026-08-11",
    "`0.6.5` | 2026-07-29",
    "`0.6.4` | 2026-07-26"
  ]
}.freeze

FORBIDDEN_TEXT = {
  "src/docs/solverforge/index.md" => ["solverforge 0.19.1", "solverforge-cli 2.2.2"],
  "src/docs/solverforge-python/index.md" => ["solverforge-py 0.6.3", "solverforge==0.6.3"],
  "src/docs/solverforge-cli/command-reference.md" => ["solverforge-cli 2.2.2", "crate target 0.15.2"],
  "src/docs/status-and-roadmap.md" => [
    "solverforge-py 0.6.3",
    "solverforge 0.19.1",
    "solverforge-cli 2.2.2` package",
    "solverforge-hospital@2.0.6",
    "solverforge-lessons@2.0.6",
    "solverforge-deliveries@2.0.6",
    "solverforge-fsr@2.0.7"
  ],
  "src/docs/getting-started/solverforge-hospital-use-case.md" => ["solverforge-hospital@2.0.6"],
  "src/docs/getting-started/solverforge-lessons-use-case.md" => ["solverforge-lessons@2.0.6"],
  "src/docs/getting-started/solverforge-deliveries-use-case.md" => ["solverforge-deliveries@2.0.6"],
  "src/docs/getting-started/solverforge-fsr-use-case.md" => ["solverforge-fsr@2.0.7"]
}.freeze

failures = []

REQUIRED_TEXT.each do |relative_path, needles|
  path = File.join(ROOT, relative_path)
  unless File.file?(path)
    failures << "missing file: #{relative_path}"
    next
  end

  text = File.read(path)
  needles.each do |needle|
    failures << "#{relative_path} is missing #{needle.inspect}" unless text.include?(needle)
  end
end

FORBIDDEN_TEXT.each do |relative_path, needles|
  path = File.join(ROOT, relative_path)
  unless File.file?(path)
    failures << "missing file: #{relative_path}"
    next
  end

  text = File.read(path)
  needles.each do |needle|
    failures << "#{relative_path} still contains #{needle.inspect}" if text.include?(needle)
  end
end

unless failures.empty?
  warn "[verify-release-surface] ERROR"
  failures.each { |failure| warn "- #{failure}" }
  exit 1
end

puts "[verify-release-surface] Verified #{REQUIRED_TEXT.length} current release surfaces"
