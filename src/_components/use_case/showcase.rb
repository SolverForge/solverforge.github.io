class UseCase::Showcase < Bridgetown::Component
  # One slide per use case: metrics strip, constraint summary, narrated runtime
  # walkthrough, and annotated screenshots. Content lives in
  # src/_data/use_cases.yml so the page template stays declarative.
  def initialize(cases:)
    @cases = cases
  end

  def cases
    @cases
  end

  # A component nested in this one (UseCase::Demoscene) resolves URLs through its
  # view context's site, which a component only has when it exposes one.
  def site
    helpers.site
  end

  def first_id
    @cases.first.fetch("id")
  end

  def videos?(use_case)
    !use_case.fetch("runtime")["video"].to_s.empty?
  end

  # The marker sits exactly on the measured point, so the reader can always tell
  # which part of the interface the numbered legend line describes.
  def marker_style(callout)
    %(--use-case-callout-top: #{callout.fetch('top')}%; --use-case-callout-left: #{callout.fetch('left')}%)
  end

  # Every SolverForge use case is open source, so the page distinguishes cases
  # by whether they expose a Hugging Face Space you can drive in the browser.
  def space?(use_case)
    !use_case["space_url"].to_s.empty?
  end

  # The demoscene case is a product, not a web demo: it renders its intro video,
  # a cue sheet, and plain captures through UseCase::Demoscene instead of the
  # narrated walkthrough and annotated screenshots.
  def demoscene?(use_case)
    use_case["variant"] == "demoscene"
  end

  def selector_class(use_case)
    [
      "use-case-carousel__selector",
      ("use-case-carousel__selector--space" if space?(use_case)),
      ("use-case-carousel__selector--demoscene" if demoscene?(use_case)),
    ].compact.join(" ")
  end
end
