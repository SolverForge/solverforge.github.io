class UseCase::Demoscene < Bridgetown::Component
  # The demoscene case (`variant: demoscene` in src/_data/use_cases.yml) shows a
  # product rather than a web demo: its intro video with a cue sheet that seeks
  # it, and plain captures of the real app. The carousel slide and the case page
  # both render it from here, so the two surfaces cannot disagree.
  #
  # part: :stage renders the video and cue sheet (through Media::DemosceneVideo),
  # :captures the app captures.
  def initialize(use_case:, part:)
    @use_case = use_case
    @part = part
  end

  # Media::DemosceneVideo, rendered from here, resolves URLs through its view
  # context's site, which a component only has when it exposes one.
  def site
    helpers.site
  end

  def stage?
    @part == :stage
  end

  def runtime
    @use_case.fetch("runtime")
  end

  def cues
    @use_case.fetch("cues")
  end

  def captures
    @use_case.fetch("captures")
  end

  def label
    @use_case.fetch("label")
  end
end
