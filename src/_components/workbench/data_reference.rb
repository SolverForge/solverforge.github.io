# A model's dataset format as the engine describes it: every table at its JSON
# path with every field the model reads, the model's parameters and its demo.
class Workbench::DataReference < Bridgetown::Component
  def initialize(site:, model:)
    @model = Workbench::Data.model(site, model)
  end

  attr_reader :model

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
