# The search over one model's constraints, above its constraints page. The
# page reads in full without JavaScript; workbench.js folds each constraint
# under its name and filters them with the Workbench's own fuzzy match.
class Workbench::RulesToolbar < Bridgetown::Component
  def initialize(site:, model:)
    @model = Workbench::Data.model(site, model)
  end

  attr_reader :model

  def counts
    Workbench::Data.counts(@model)
  end

  def levels
    Workbench::Data::LEVELS
  end
end
