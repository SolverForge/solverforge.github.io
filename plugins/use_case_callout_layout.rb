# frozen_string_literal: true

# Screenshot annotations render as numbered markers on the capture plus a legend
# list beside it. Positioning free-text boxes over the image was the earlier
# approach and it does not work at the size the two-column grid produces: two
# 190px labels on a 579px-wide frame collide constantly, and a box sitting on the
# image hides the very region its dot claims to mark.
#
# Numbers remove the problem rather than tune it. A marker is small enough to sit
# exactly on the measured point, the legend carries the text at a readable size,
# and the pairing between a marker and its line is explicit.
module UseCaseCalloutLayout
  # Markers are numbered from 1 within each capture.
  def self.number(callouts)
    callouts.each_with_index.map do |callout, index|
      callout.merge("marker" => index + 1)
    end
  end
end
