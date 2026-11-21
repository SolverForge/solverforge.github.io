# One stock model as the engine describes it: its demo, every constraint by
# group with its level and what it costs, the data tables a dataset holds, and
# the model's parameters.
class Workbench::Model < Bridgetown::Component
  def initialize(site:, id:)
    @site = site
    @model = Workbench::Data.model(site, id)
  end

  attr_reader :model

  def site
    @site
  end

  def counts
    Workbench::Data.counts(@model)
  end

  def groups
    Workbench::Data.groups(@model)
  end

  def anchor(constraint)
    Workbench::Data.rule_anchor(constraint)
  end

  def group_anchor(group)
    Workbench::Data.group_anchor(group)
  end

  def off?(constraint)
    Workbench::Data.off_by_default?(constraint)
  end

  def explorer_url
    relative_url("/docs/solverforge-workbench/constraints/?model=#{@model["id"]}")
  end

  # The field's kind in words: "list of objects", "minutes", "date time"...
  def kind(column)
    case column["kind"]
    when "list"
      inner = (column["fields"] || []).first
      inner && inner["kind"] == "object" ? "list of objects" : "list"
    else
      text = column["kind"].to_s.tr("_", " ")
      column["unit"] && column["unit"] != column["kind"] ? "#{text} (#{column["unit"]})" : text
    end
  end

  # The fields inside an object or a list's items, by JSON name.
  def subfields(column)
    inner = column["fields"] || []
    inner = inner.first["fields"] || [inner.first] if column["kind"] == "list" && inner.first
    inner.map { |f| f["name"] }.join(", ")
  end

  # Allowed values, or the table an id refers to.
  def values(column)
    item = column["kind"] == "list" ? (column["fields"] || []).first || column : column
    return "an id from #{item["reference"]}" if item["reference"]
    (column["options"] || []).join(", ")
  end
end
