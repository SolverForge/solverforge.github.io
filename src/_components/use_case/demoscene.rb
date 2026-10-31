class UseCase::Demoscene < Bridgetown::Component
  # The demoscene case (`variant: demoscene` in src/_data/use_cases.yml) shows a
  # product rather than a web demo: its intro video with a cue sheet that seeks
  # it, and plain captures of the real app. The carousel slide and the case page
  # both render it from here, so the two surfaces cannot disagree.
  #
  # part: :stage renders the video and cue sheet, :captures the app captures.
  def initialize(use_case:, part:)
    @use_case = use_case
    @part = part
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
