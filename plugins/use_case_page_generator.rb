# frozen_string_literal: true

# One streamlined page per use case, generated from src/_data/use_cases.yml so
# the showcase carousel and the individual pages can never disagree about a
# case's metrics, constraints, captures, or walkthrough.
#
# Each page renders the case's own proof: the data shape, the constraint
# summary, the annotated captures with their viewer, and the narrated
# walkthrough, plus links to the guide and the app source.
class UseCasePageGenerator < Bridgetown::Generator
  priority :low

  def generate(site)
    @site = site
    cases = site.data["use_cases"]
    return unless cases.is_a?(Array)

    cases.each do |use_case|
      page = build_page(use_case)
      site.add_generated_page(page)
    end
  end

  private

  def build_page(use_case)
    id = use_case.fetch("id")
    page = Bridgetown::GeneratedPage.new(@site, @site.source, "use-cases/#{id}", "index.html")
    page.data = Bridgetown::Utils.deep_merge_hashes(
      page.data,
      {
        "title" => "#{use_case.fetch('label')} use case",
        "layout" => "use_case",
        "page_class" => "page-use-case",
        "description" => use_case.fetch("intro"),
        "use_case" => use_case,
      }
    )
    page.content = ""
    page
  end
end
