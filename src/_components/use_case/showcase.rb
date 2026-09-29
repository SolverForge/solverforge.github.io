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
    %(--use-case-callout-top: #{callout.fetch('top')}%; --use-case-callout-left: #{callout.fetch('left')}%)
  end

  # A callout is anchored by its dot, which sits 20px right and 5px above the
  # box corner. Boxes in the right half grow leftward and boxes in the lower
  # third grow upward, so an annotation near a frame edge cannot spill out of the
  # frame when the capture is displayed at half width.
  def callout_class(callout)
    classes = ["use-case-showcase__callout"]
    classes << "use-case-showcase__callout--right" if callout.fetch("left").to_f > 50
    classes << "use-case-showcase__callout--low" if callout.fetch("top").to_f > 65
    classes.join(" ")
  end

  # Every SolverForge use case is open source, so the page distinguishes cases
  # by whether they expose a Hugging Face Space you can drive in the browser.
  def space?(use_case)
    !use_case["space_url"].to_s.empty?
  end
end
