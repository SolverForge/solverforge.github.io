class Shared::SearchSurface < Bridgetown::Component
  SCOPES = [
    ["all", "All"],
    ["docs", "Docs"],
    ["reference", "Reference"],
    ["blog", "Blog"],
    ["pages", "Pages"],
  ].freeze

  QUICK_LINKS = [
    ["/docs/overview/", "Project overview", "Understand the planning problems SolverForge handles and when to use it."],
    ["/docs/getting-started/solverforge-hospital-use-case/", "SolverForge Hospital Use Case", "See a concrete hospital scheduling application from scaffold to solver-driven UI."],
    ["/docs/getting-started/solverforge-deliveries-use-case/", "SolverForge Deliveries Use Case", "Study list-variable vehicle routing with maps, retained jobs, and route recommendations."],
    ["/reference/", "Reference docs", "Check crate boundaries, modeling choices, and extension guidance."],
    ["/blog/", "Release notes and technical posts", "Review shipped changes and implementation decisions."],
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
