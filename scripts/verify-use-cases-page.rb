#!/usr/bin/env ruby
# frozen_string_literal: true

# Contract for the /use-cases/ showcase: the data file behind the carousel, the
# assets it points at, and the cross-references it promises. The rendered
# carousel behaviour (slides, lightbox, annotations) is asserted in
# scripts/check-public-pages.mjs, which runs against the built output.

require "yaml"

ROOT = File.expand_path("..", __dir__)

DATA_PATH = "src/_data/use_cases.yml"
EXPECTED_CASES = %w[hospital lessons deliveries field-service].freeze
EXPECTED_DOCS = {
  "hospital" => ["/docs/getting-started/solverforge-hospital-use-case/", "src/docs/getting-started/solverforge-hospital-use-case.md"],
  "lessons" => ["/docs/getting-started/solverforge-lessons-use-case/", "src/docs/getting-started/solverforge-lessons-use-case.md"],
  "deliveries" => ["/docs/getting-started/solverforge-deliveries-use-case/", "src/docs/getting-started/solverforge-deliveries-use-case.md"],
  "field-service" => ["/docs/getting-started/solverforge-fsr-use-case/", "src/docs/getting-started/solverforge-fsr-use-case.md"]
}.freeze
EXPECTED_METRICS = 6
EXPECTED_CONSTRAINTS = 6
MINIMUM_SCREENSHOTS = 6

def source_path(asset_url)
  File.join(ROOT, "src", asset_url.sub(%r{\A/}, ""))
end

failures = []

data_file = File.join(ROOT, DATA_PATH)
unless File.file?(data_file)
  warn "[verify-use-cases] ERROR"
  warn "- missing file: #{DATA_PATH}"
  exit 1
end

cases = YAML.load_file(data_file)
failures << "#{DATA_PATH} must define an array of cases" unless cases.is_a?(Array)

ids = cases.map { |use_case| use_case["id"] }
failures << "#{DATA_PATH} cases #{ids.inspect} != #{EXPECTED_CASES.inspect}" unless ids == EXPECTED_CASES

REQUIRED_TEXT_FIELDS = %w[id label eyebrow title intro docs_url space_url teaser_metric teaser_copy icon].freeze

cases.each do |use_case|
  id = use_case["id"] || "(missing id)"

  REQUIRED_TEXT_FIELDS.each do |field|
    value = use_case[field]
    failures << "#{id}: missing or empty #{field}" if value.to_s.strip.empty?
  end

  metrics = use_case["metrics"]
  unless metrics.is_a?(Array) && metrics.length == EXPECTED_METRICS
    failures << "#{id}: expected #{EXPECTED_METRICS} metrics, found #{metrics.is_a?(Array) ? metrics.length : 0}"
  end
  Array(metrics).each do |value, label|
    failures << "#{id}: metric #{value.to_s.inspect} is missing a label" if label.to_s.strip.empty?
  end

  constraints = use_case["constraints"]
  unless constraints.is_a?(Array) && constraints.length == EXPECTED_CONSTRAINTS
    failures << "#{id}: expected #{EXPECTED_CONSTRAINTS} constraints, found #{constraints.is_a?(Array) ? constraints.length : 0}"
  end
  Array(constraints).each do |name, copy|
    failures << "#{id}: constraint #{name.to_s.inspect} is missing its description" if copy.to_s.strip.empty?
  end

  docs_target = EXPECTED_DOCS[id]
  failures << "#{id}: unexpected docs_url #{use_case['docs_url'].inspect}" unless docs_target && use_case["docs_url"] == docs_target[0]
  failures << "#{id}: docs guide is missing at #{docs_target[1]}" unless docs_target && File.file?(File.join(ROOT, docs_target[1]))

  space_url = use_case["space_url"].to_s
  unless space_url.start_with?("https://huggingface.co/spaces/SolverForge/solverforge-")
    failures << "#{id}: space_url #{space_url.inspect} is not a SolverForge Hugging Face Space"
  end

  runtime = use_case["runtime"] || {}
  %w[video poster label copy caption].each do |field|
    failures << "#{id}: runtime is missing #{field}" if runtime[field].to_s.strip.empty?
  end
  %w[video poster].each do |field|
    asset = runtime[field].to_s
    next if asset.empty?
    failures << "#{id}: runtime #{field} not found at #{asset}" unless File.file?(source_path(asset))
  end

  screenshots = use_case["screenshots"]
  unless screenshots.is_a?(Array) && screenshots.length >= MINIMUM_SCREENSHOTS
    failures << "#{id}: expected at least #{MINIMUM_SCREENSHOTS} annotated screenshots, found #{screenshots.is_a?(Array) ? screenshots.length : 0}"
  end

  Array(screenshots).each_with_index do |shot, index|
    label = "#{id} screenshot #{index + 1}"
    %w[image badge alt caption].each do |field|
      failures << "#{label}: missing #{field}" if shot[field].to_s.strip.empty?
    end

    image = shot["image"].to_s
    failures << "#{label}: image not found at #{image}" unless image.empty? || File.file?(source_path(image))

    callouts = shot["callouts"]
    unless callouts.is_a?(Array) && callouts.length >= 2
      failures << "#{label}: expected at least 2 annotated callouts"
      next
    end

    callouts.each do |callout|
      failures << "#{label}: callout text is empty" if callout["text"].to_s.strip.empty?
      %w[top left].each do |axis|
        value = callout[axis]
        next if value.is_a?(Numeric) && value >= 0 && value <= 100

        failures << "#{label}: callout #{axis} #{value.inspect} must be a percentage between 0 and 100"
      end
    end
  end
end

# The page, the component, and the navigation must stay wired to the data file.
PAGE_WIRING = {
  "src/use-cases.md" => ["layout: use_cases", "UseCase::Showcase.new(cases: site.data.use_cases)"],
  "src/_components/use_case/showcase.erb" => ["data-use-case-carousel", "data-use-case-lightbox-root", "use-case-showcase__callout"],
  "frontend/styles/index.scss" => ["use-case-space-ribbon"],
  "src/_layouts/use_cases.erb" => ["page-shell--use-cases"],
  "src/_data/navigation.yml" => ["url: /use-cases/"],
  "src/index.md" => ["site.data.use_cases"]
}.freeze

PAGE_WIRING.each do |relative_path, needles|
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

if failures.any?
  warn "[verify-use-cases] ERROR"
  failures.each { |failure| warn "- #{failure}" }
  exit 1
end

puts "[verify-use-cases] Verified #{cases.length} use cases, " \
     "#{cases.sum { |use_case| use_case['screenshots'].length }} annotated screenshots, " \
     "and their runtime walkthroughs"
