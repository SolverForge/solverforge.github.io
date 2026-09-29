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

  def first_id
    @cases.first.fetch("id")
  end

  def videos?(use_case)
    !use_case.fetch("runtime")["video"].to_s.empty?
  end

  def callout_style(callout)
    "--use-case-callout-top: #{callout.fetch('top')}%; --use-case-callout-left: #{callout.fetch('left')}%"
  end

  # Every SolverForge use case is open source, so the page distinguishes cases
  # by whether they expose a Hugging Face Space you can drive in the browser.
  def space?(use_case)
    !use_case["space_url"].to_s.empty?
  end
end
