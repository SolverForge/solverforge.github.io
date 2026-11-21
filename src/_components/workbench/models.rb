# The four stock models with their constraint counts, linking each model page.
class Workbench::Models < Bridgetown::Component

  def initialize(site:)
    @site = site
  end

  def site
    @site
  end

  def rows
    Workbench::Data.models(@site)
  end

  def counts(model)
    Workbench::Data.counts(model)
  end

  def groups(model)
    Workbench::Data.groups(model).size
  end
end
