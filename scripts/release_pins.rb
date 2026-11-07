# frozen_string_literal: true

require "json"
require "net/http"
require "rubygems/version"
require "uri"

# The published versions the current-release pages claim. Every gate that
# checks a "current" sentence builds its needle from these pins, and
# `ReleasePins.check_registry!` compares each pin with the crates.io sparse
# index. When a crate publishes a newer version the gates fail and name the pin
# to move, so a stale "current" claim cannot stay green.
module ReleasePins
  CURRENT = {
    "solverforge" => "0.24.0",
    "solverforge-cli" => "3.8.3",
    "solverforge-ui" => "0.9.1",
    "solverforge-maps" => "2.3.3"
  }.freeze

  RUNTIME = CURRENT.fetch("solverforge")
  CLI = CURRENT.fetch("solverforge-cli")
  UI = CURRENT.fetch("solverforge-ui")
  MAPS = CURRENT.fetch("solverforge-maps")

  module_function

  def index_url(crate)
    prefix = case crate.length
             when 1 then "1"
             when 2 then "2"
             when 3 then "3/#{crate[0]}"
             else "#{crate[0, 2]}/#{crate[2, 2]}"
             end
    "https://index.crates.io/#{prefix}/#{crate}"
  end

  # Greatest non-yanked, non-prerelease version in the sparse index.
  def registry_head(crate)
    response = Net::HTTP.get_response(URI(index_url(crate)))
    raise "crates.io index answered #{response.code} for #{crate}" unless response.is_a?(Net::HTTPSuccess)

    rows = response.body.lines.map { |line| JSON.parse(line) }
    stable = rows.reject { |row| row.fetch("yanked") || row.fetch("vers").include?("-") }
    raise "crates.io lists no stable #{crate} release" if stable.empty?

    stable.max_by { |row| Gem::Version.new(row.fetch("vers")) }
  end

  # Returns a list of failure strings; empty when every pin is the registry head.
  def registry_failures
    CURRENT.filter_map do |crate, pinned|
      head = registry_head(crate).fetch("vers")
      next if head == pinned

      "crates.io publishes #{crate} #{head}, but scripts/release_pins.rb pins #{pinned}: " \
        "update the pin and every page that states the current #{crate} version"
    rescue StandardError => e
      "could not read the crates.io index for #{crate}: #{e.message}"
    end
  end
end
