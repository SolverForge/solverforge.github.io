# One search across the four models' constraints, on the section's front
# page. It lists nothing until you type; results are grouped by model and link
# to the constraint's explanation on its model's constraints page.
class Workbench::Search < Bridgetown::Component
  def initialize(site:)
    @site = site
  end

  def site
    @site
  end

  def total
    Workbench::Data.models(@site).sum { |m| m["constraints"].size }
  end

  def index
    Workbench::Data.models(@site).flat_map do |model|
      model["constraints"].map do |rule|
        {
          name: rule["name"],
          group: rule["group"],
          level: rule["level"],
          model: model["id"],
          modelName: model["name"],
          description: rule["description"],
          url: relative_url("#{Workbench::Data.constraints_url(model["id"])}##{Workbench::Data.rule_anchor(rule)}"),
        }
      end
    end
  end
end
