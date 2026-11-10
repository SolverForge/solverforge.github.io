#!/usr/bin/env ruby
# frozen_string_literal: true

# Contract for the videos in src/_data/demo_videos.yml that are not a use case
# (the describe, solve, repair session). It checks the data, reads the MP4
# itself (codec, faststart, duration) so a truncated or wrong encode fails, and
# checks the pages that show the video. Clicking a scene and the rendered
# players are asserted in scripts/check-public-pages.mjs.

require "yaml"

ROOT = File.expand_path("..", __dir__)
DATA_PATH = "src/_data/demo_videos.yml"
SESSION = "describe_solve_repair"
# The session ran on these releases. They are history, not the current pins:
# the caption must keep saying what the run used.
SESSION_VERSIONS = ["solverforge 0.25.1", "solverforge-cli 3.9.0"].freeze
MAX_VIDEO_BYTES = 16 * 1024 * 1024

# Every page that shows the session, and what wires it there.
WIRING = {
  "src/docs/solverforge-cli/agent-skill.md" => [
    "## Watch One Session",
    %(Media::DemosceneVideo.from_data(site.data.demo_videos["describe_solve_repair"]))
  ],
  "src/index.md" => ["data-home-session-video", %(site.data.demo_videos["describe_solve_repair"]), "/docs/solverforge-cli/agent-skill/#watch-one-session"],
  "src/docs/getting-started/maintenance-planning-with-the-agent-skill.md" => ["(/docs/solverforge-cli/agent-skill/#watch-one-session)"],
  "src/_components/media/demoscene_video.erb" => ["data-demoscene", "data-demoscene-video", "data-demoscene-cue"],
  "src/_components/use_case/demoscene.erb" => ["Media::DemosceneVideo.new"]
}.freeze

failures = []

def source_path(asset_url)
  File.join(ROOT, "src", asset_url.sub(%r{\A/}, ""))
end

# Top-level MP4 boxes in file order: [[type, offset, size], ...].
def mp4_boxes(bytes, from = 0, to = bytes.bytesize)
  boxes = []
  offset = from
  while offset + 8 <= to
    size, type = bytes.byteslice(offset, 8).unpack("Na4")
    size = bytes.byteslice(offset + 8, 8).unpack1("Q>") if size == 1
    size = to - offset if size.zero?
    break if size < 8

    boxes << [type, offset, size]
    offset += size
  end
  boxes
end

# Duration in seconds from the movie header (mvhd, version 0 or 1).
def mp4_duration(bytes, moov)
  _, offset, size = moov
  mvhd = mp4_boxes(bytes, offset + 8, offset + size).find { |type, *| type == "mvhd" }
  return nil unless mvhd

  body = mvhd[1] + 8
  version = bytes.getbyte(body)
  if version == 1
    timescale, duration = bytes.byteslice(body + 20, 12).unpack("NQ>")
  else
    timescale, duration = bytes.byteslice(body + 12, 8).unpack("NN")
  end
  duration.to_f / timescale
end

data = YAML.safe_load_file(File.join(ROOT, DATA_PATH))
session = data[SESSION]
if session.nil?
  failures << "#{DATA_PATH} has no #{SESSION} entry"
  session = {}
end

%w[name video poster duration label copy note cues].each do |field|
  failures << "#{SESSION}: missing #{field}" if session[field].to_s.strip.empty?
end

SESSION_VERSIONS.each do |version|
  failures << "#{SESSION}: the note must say the run used #{version}" unless session["note"].to_s.include?(version)
end
failures << "#{SESSION}: the label must carry the length #{session['duration']}" unless session["label"].to_s.end_with?(session["duration"].to_s)

# The first-feasible timing measures the solver, not app generation or build.
copy = session["copy"].to_s
unless copy.match?(/Once the app is built and running, its solver finds the first feasible\s+plan in 153 ms\./)
  failures << "#{SESSION}: scope 153 ms to the solver after the app is built and running"
end

poster = session["poster"].to_s
failures << "#{SESSION}: poster not found at #{poster}" unless !poster.empty? && File.file?(source_path(poster))

video_seconds = nil
video = session["video"].to_s
video_path = source_path(video)
if video.empty? || !File.file?(video_path)
  failures << "#{SESSION}: video not found at #{video}"
else
  bytes = File.binread(video_path)
  failures << "#{SESSION}: video is #{bytes.bytesize} bytes, over the #{MAX_VIDEO_BYTES} byte budget" if bytes.bytesize > MAX_VIDEO_BYTES
  boxes = mp4_boxes(bytes)
  types = boxes.map(&:first)
  moov = boxes.find { |type, *| type == "moov" }
  if moov.nil? || !types.include?("mdat")
    failures << "#{SESSION}: video has no moov/mdat boxes"
  else
    failures << "#{SESSION}: video is not faststart (moov after mdat)" unless types.index("moov") < types.index("mdat")
    moov_bytes = bytes.byteslice(moov[1], moov[2])
    failures << "#{SESSION}: video track is not H.264 (no avc1 sample entry)" unless moov_bytes.include?("avc1")
    failures << "#{SESSION}: video has no AAC audio (no mp4a sample entry)" unless moov_bytes.include?("mp4a")
    video_seconds = mp4_duration(bytes, moov)
    stated = session["duration"].to_s.split(":").map(&:to_i)
    stated_seconds = stated.size == 2 ? stated[0] * 60 + stated[1] : -1
    if video_seconds.nil? || (video_seconds - stated_seconds).abs > 1
      failures << "#{SESSION}: video runs #{video_seconds&.round(2)} s, not the stated #{session['duration']}"
    end
  end
end

# A scene seeks the video, so it has to start at a real, increasing time inside
# the video, and its label is that time as the reader sees it.
cues = session["cues"]
unless cues.is_a?(Array) && !cues.empty?
  failures << "#{SESSION}: needs a scene list"
  cues = []
end
previous = -1
cues.each_with_index do |cue, index|
  at = cue["at"]
  unless at.is_a?(Numeric) && at > previous
    failures << "#{SESSION} scene #{index + 1}: start #{at.inspect} must be a number after the previous scene"
    next
  end
  failures << "#{SESSION}: the first scene must start the video at 0" if index.zero? && at != 0
  failures << "#{SESSION} scene #{index + 1}: starts at #{at} s, after the video ends" if video_seconds && at >= video_seconds
  previous = at
  seconds = at.round
  label = format("%d:%02d", seconds / 60, seconds % 60)
  failures << "#{SESSION} scene #{index + 1}: label #{cue['label'].inspect} != #{label}" unless cue["label"] == label
  failures << "#{SESSION} scene #{index + 1}: missing text" if cue["text"].to_s.strip.empty?
end

WIRING.each do |relative_path, needles|
  path = File.join(ROOT, relative_path)
  unless File.file?(path)
    failures << "missing file: #{relative_path}"
    next
  end
  text = File.read(path)
  needles.each { |needle| failures << "#{relative_path} is missing #{needle.inspect}" unless text.include?(needle) }
end

if failures.any?
  warn "[verify-demo-videos] ERROR"
  failures.each { |failure| warn "- #{failure}" }
  exit 1
end

puts "[verify-demo-videos] Verified #{SESSION}: #{File.size(video_path)} bytes, " \
     "#{video_seconds.round(2)} s, H.264/AAC faststart, #{cues.size} scenes, #{WIRING.size} wired files"
