# A model's constraint groups with their counts, each linking to the group on
# the model's constraints page.
class Workbench::Groups < Bridgetown::Component
  def initialize(site:, model:)
    @model = Workbench::Data.model(site, model)
  end

  attr_reader :model

  def groups
    Workbench::Data.groups(@model)
  end

  def counts
    Workbench::Data.counts(@model)
  end

  def url(group = nil)
    base = relative_url(Workbench::Data.constraints_url(@model["id"]))
    group ? "#{base}##{Workbench::Data.group_anchor(group)}" : base
  end

  def levels(rules)
    Workbench::Data::LEVELS.filter_map do |level|
      n = rules.count { |r| r["level"] == level }
      "#{n} #{level}" if n.positive?
    end.join(", ")
  end
end
