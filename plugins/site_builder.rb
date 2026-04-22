# frozen_string_literal: true

require "cgi"
require "json"
require "fileutils"
require "time"

class SiteBuilder < Bridgetown::Builder
  SEARCH_INDEX_PATH = "search-index.json"
  EXCLUDED_SEARCH_PATHS = ["/404.html", "/500.html", "/search/"].freeze
  KIND_LABELS = {
    "docs" => "Documentation",
    "reference" => "Reference",
    "blog" => "Blog",
    "pages" => "Pages",
  }.freeze
  KIND_PRIORITIES = {
    "docs" => 42,
    "reference" => 34,
    "pages" => 26,
    "blog" => 20,
  }.freeze
  SPECIAL_GROUP_LABELS = {
    "concepts" => "Concepts",
    "getting-started" => "Getting Started",
    "solverforge" => "SolverForge",
    "solverforge-cli" => "solverforge-cli",
    "solverforge-ui" => "solverforge-ui",
    "solverforge-maps" => "solverforge-maps",
    "bridgetown" => "Bridgetown",
  }.freeze
  STOPWORDS = %w[
    a an and are as at be but by for from if in into is it its of on or our s so
    that the their there these this to was we with you your
  ].freeze

  def write_search_index(current_site)
    documents = current_site.collections.values
      .flat_map(&:resources)
      .select { |resource| indexable_resource?(resource) }
      .flat_map { |resource| build_search_documents(resource) }
      .sort_by { |document| [-document["priority"], document["title"], document["section"].to_s] }

    payload = {
      "generated_at" => Time.now.utc.iso8601,
      "version" => 1,
      "total_documents" => documents.length,
      "documents" => documents,
    }

    output_path = current_site.in_dest_dir(SEARCH_INDEX_PATH)
    FileUtils.mkdir_p(File.dirname(output_path))
    File.write(output_path, JSON.generate(payload))
  end

  private

  def indexable_resource?(resource)
    return false unless resource.destination

    destination_path = resource.destination.output_path

    resource.write? &&
      resource.output_ext == ".html" &&
      File.file?(destination_path) &&
      !resource.data["search_exclude"] &&
      !EXCLUDED_SEARCH_PATHS.include?(resource.relative_url)
  end

  def build_search_documents(resource)
    html = File.read(resource.destination.output_path)
    main_html = extract_primary_html(html)
    return [] if main_html.empty?

    title = clean_text(resource.data.title.to_s)
    title = labelize_segment(resource.relative_path.basename(".md").to_s) if title.empty?

    description = clean_text(resource.data.description.to_s)
    kind = classify_resource(resource)
    kind_label = KIND_LABELS.fetch(kind)
    group_label = group_label_for(resource, kind)
    date = kind == "blog" ? resource.data["date"] : nil
    date_display = date.respond_to?(:strftime) ? date.strftime("%B %-d, %Y") : nil
    date_iso = date.respond_to?(:strftime) ? date.strftime("%F") : nil
    tags = Array(resource.data["tags"]).map(&:to_s)
    sections = extract_sections(main_html)

    intro_html =
      if sections.any?
        main_html[0...sections.first.fetch(:offset)]
      else
        main_html
      end
    intro_text = clean_text(intro_html)
    intro_text = clean_text(main_html) if intro_text.empty?

    page_entry = build_entry(
      resource:,
      kind:,
      kind_label:,
      group_label:,
      title:,
      description:,
      excerpt: excerpt_for(description, intro_text),
      search_text: [
        title,
        description,
        group_label,
        intro_text,
        sections.map { |section| section[:title] }.join(" "),
      ].join(" "),
      tags:,
      date_display:,
      date_iso:
    )

    section_entries = sections.filter_map do |section|
      body_text = clean_text(section[:body_html])
      next if body_text.length < 36

      build_entry(
        resource:,
        kind:,
        kind_label:,
        group_label:,
        title:,
        section: section[:title],
        description:,
        excerpt: excerpt_for(section[:title], body_text),
        search_text: [
          title,
          section[:title],
          description,
          group_label,
          body_text,
        ].join(" "),
        tags:,
        date_display:,
        date_iso:,
        anchor: section[:id]
      )
    end

    [page_entry, *section_entries]
  end

  def build_entry(resource:, kind:, kind_label:, group_label:, title:, description:, excerpt:, search_text:,
                  tags:, date_display:, date_iso:, section: nil, anchor: nil)
    url = resource.relative_url
    url = "#{url}##{anchor}" if anchor

    normalized_text = normalize_text(search_text)
    {
      "id" => [resource.relative_url, anchor].compact.join("#"),
      "page_url" => resource.relative_url,
      "url" => url,
      "kind" => kind,
      "kind_label" => kind_label,
      "group_label" => group_label,
      "title" => title,
      "section" => section,
      "description" => description,
      "excerpt" => excerpt,
      "date_display" => date_display,
      "date_iso" => date_iso,
      "tags" => tags,
      "entry_type" => anchor ? "section" : "page",
      "priority" => priority_for(resource, kind, section: !anchor.nil?),
      "search_title" => normalize_text(title),
      "search_section" => normalize_text(section),
      "search_text" => normalized_text[0, anchor ? 1200 : 1800],
      "terms" => build_terms(
        title,
        group_label,
        section,
        description,
        tags.join(" "),
        normalized_text
      ),
    }
  end

  def classify_resource(resource)
    case resource.relative_url
    when %r{\A/docs/}
      "docs"
    when %r{\A/reference/}
      "reference"
    when %r{\A/blog/}
      "blog"
    else
      "pages"
    end
  end

  def priority_for(resource, kind, section:)
    priority = KIND_PRIORITIES.fetch(kind, 10)
    priority += 7 if resource.relative_url == "/"
    priority += 5 if resource.relative_url == "/docs/overview/"
    priority += 4 if resource.relative_url == "/reference/"
    priority += 3 if section
    priority
  end

  def group_label_for(resource, kind)
    return labelize_segment(Array(resource.data["categories"]).first) if kind == "blog"

    segments = resource.relative_url.split("/").reject(&:empty?)
    return if segments.length < 3

    group_segment = segments[1]
    return if group_segment.nil?

    labelize_segment(group_segment)
  end

  def labelize_segment(segment)
    return if segment.nil? || segment.empty?

    SPECIAL_GROUP_LABELS.fetch(segment) do
      segment
        .tr("_", "-")
        .split("-")
        .reject(&:empty?)
        .map { |part| part.length <= 3 ? part.upcase : part.capitalize }
        .join(" ")
    end
  end

  def extract_primary_html(html)
    [
      %r{<article\b[^>]*class="[^"]*docs-shell__content[^"]*"[^>]*>(.*)</article>}mi,
      %r{<article\b[^>]*class="[^"]*post-shell[^"]*"[^>]*>(.*)</article>}mi,
      %r{<article\b[^>]*class="[^"]*page-shell[^"]*"[^>]*>(.*)</article>}mi,
      %r{<section\b[^>]*class="[^"]*home-shell[^"]*"[^>]*>(.*)</section>}mi,
    ].each do |pattern|
      match = html.match(pattern)
      return match[1].to_s if match
    end

    match = html.match(%r{<main\b[^>]*>(.*)</main>}mi)
    match ? match[1].to_s : html.to_s
  end

  def extract_sections(html)
    heading_matches = html.to_enum(:scan, /<h(2)([^>]*)>(.*?)<\/h\1>/mi).map { Regexp.last_match }

    heading_matches.filter_map.with_index do |match, index|
      title = clean_text(match[3])
      next if title.empty?

      level = match[1].to_i
      next_offset = next_section_offset(heading_matches, index, level, html.length)
      body_html = html[match.end(0)...next_offset].to_s
      section_id = match[2][/id=(["'])(.*?)\1/i, 2] || fallback_anchor(title)

      {
        level:,
        offset: match.begin(0),
        title:,
        id: section_id,
        body_html:,
      }
    end
  end

  def next_section_offset(matches, current_index, level, html_length)
    following_match = matches[(current_index + 1)..]&.find { |candidate| candidate[1].to_i <= level }
    following_match ? following_match.begin(0) : html_length
  end

  def excerpt_for(prefix, body_text, limit: 220)
    excerpt = [prefix, body_text].compact.reject(&:empty?).join(" ").strip
    excerpt = collapse_whitespace(excerpt)
    return excerpt if excerpt.length <= limit

    "#{excerpt[0, limit].sub(/\s+\S*\z/, "").strip}…"
  end

  def build_terms(*chunks)
    counts = Hash.new(0)

    chunks.compact.each do |chunk|
      tokenize(chunk).each { |token| counts[token] += 1 }
    end

    counts
      .sort_by { |token, count| [-count, -token.length, token] }
      .first(120)
      .map(&:first)
  end

  def tokenize(text)
    normalize_text(text).scan(/[a-z0-9][a-z0-9.+#-]*/).flat_map do |token|
      token = token.gsub(/\A[.+#-]+|[.+#-]+\z/, "")
      next [] if token.empty?

      parts = token.split(/[-_:\/]/).reject(&:empty?)
      ([token] + parts).reject { |part| part.length == 1 || STOPWORDS.include?(part) }
    end.uniq
  end

  def normalize_text(text)
    text.to_s
      .downcase
      .tr("’", "'")
      .gsub("&", " and ")
      .gsub(/[^a-z0-9.+#_\-\/:\s]/, " ")
      .gsub(/\s+/, " ")
      .strip
  end

  def clean_text(html)
    text = html.to_s.dup
    text.gsub!(%r{<script.*?</script>}mi, " ")
    text.gsub!(%r{<style.*?</style>}mi, " ")
    text.gsub!(%r{<svg.*?</svg>}mi, " ")
    text.gsub!(%r{<[^>]+>}, " ")
    text = CGI.unescapeHTML(text)
    collapse_whitespace(text)
  end

  def collapse_whitespace(text)
    text.to_s.gsub(/\s+/, " ").strip
  end

  def fallback_anchor(title)
    title.downcase.gsub(/[^a-z0-9]+/, "-").gsub(/\A-+|-+\z/, "")
  end
end

Bridgetown::Hooks.register_one :site, :post_write do |current_site|
  SiteBuilder.new("SearchIndexWriter", current_site).write_search_index(current_site)
end
