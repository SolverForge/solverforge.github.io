class Media::DemosceneVideo < Bridgetown::Component
  # A demoscene video with a cue sheet that seeks it. The cue sheet doubles as a
  # chapter list: frontend/javascript/use-cases.js (initializeDemosceneCues)
  # seeks the video on click and marks the scene on screen as it plays.
  #
  # Planner123's case (UseCase::Demoscene) and the SolverForge
  # "describe, solve, repair" video (src/_data/demo_videos.yml) both render
  # through here, so the markup and behaviour cannot drift apart.
  #
  # name:   what the video is called, used to label the cue sheet
  # video:  path of the MP4
  # poster: path of the poster image
  # label:  the short tag under the video (product and length)
  # copy:   what happens in the video; also the video's aria-label
  # cues:   [{ "at" => seconds, "label" => "m:ss", "key" => optional, "text" => ... }]
  # note:   optional second caption line
  def initialize(name:, video:, poster:, label:, copy:, cues:, note: nil)
    @name = name
    @video = video
    @poster = poster
    @label = label
    @copy = copy
    @cues = cues
    @note = note
  end

  # Builds the component from one entry of src/_data/demo_videos.yml.
  def self.from_data(entry)
    new(
      name: entry.fetch("name"),
      video: entry.fetch("video"),
      poster: entry.fetch("poster"),
      label: entry.fetch("label"),
      copy: entry.fetch("copy"),
      cues: entry.fetch("cues"),
      note: entry["note"]
    )
  end

  attr_reader :name, :video, :poster, :label, :copy, :cues, :note
end
