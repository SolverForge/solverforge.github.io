class Shared::SearchSurface < Bridgetown::Component
  SCOPES = [
    ["all", "All"],
    ["docs", "Docs"],
    ["reference", "Reference"],
    ["blog", "Blog"],
    ["pages", "Pages"],
  ].freeze

  QUICK_LINKS = [
    ["/docs/overview/", "Project overview", "Read the architecture, scope, and runtime framing."],
    ["/docs/getting-started/employee-scheduling-rust/", "Employee scheduling", "Start with the full end-to-end tutorial."],
    ["/reference/", "Reference docs", "Open the engineer-facing handbooks, crate maps, and clearly labeled maintainer notes."],
    ["/blog/", "Release notes and technical posts", "Browse changes, direction, and implementation notes."],
  ].freeze

  def initialize(mode:, index_url:, page_url:)
    @mode = mode.to_s
    @index_url = index_url
    @page_url = page_url
  end

  def overlay?
    @mode == "overlay"
  end
end
