# Every constraint of the four stock models in one searchable list. The list
# is rendered whole, so it reads without JavaScript; workbench.js filters and
# ranks it with the same fuzzy match as the Workbench's own search.
class Workbench::Explorer < Bridgetown::Component
  def initialize(site:)
    @site = site
  end

  def site
    @site
  end

  def models
    Workbench::Data.models(@site)
  end

  def rules
    models.flat_map do |model|
      model["constraints"].map { |rule| [model, rule] }
    end
  end

  def url(model, rule)
    relative_url("#{Workbench::Data.page_url(model["id"])}##{Workbench::Data.rule_anchor(rule)}")
  end

  def group_url(model, rule)
    relative_url("#{Workbench::Data.page_url(model["id"])}##{Workbench::Data.group_anchor(rule["group"])}")
  end

  def off?(rule)
    Workbench::Data.off_by_default?(rule)
  end

  def levels
    Workbench::Data::LEVELS
  end

  def meaning(level)
    Workbench::Data::LEVEL_MEANING.fetch(level)
  end
end
