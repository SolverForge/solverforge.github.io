# Reads src/_data/workbench.json: the stock models as the Workbench engine
# release describes them. Every count and constraint on the Workbench pages
# comes from here.
module Workbench
  module Data
    LEVELS = %w[hard medium soft].freeze
    LEVEL_MEANING = {
      "hard" => "Must hold: a plan that breaks it is infeasible.",
      "medium" => "Work left undone: counted only after every hard rule holds.",
      "soft" => "A preference or cost, traded against the other soft rules by weight.",
    }.freeze

    module_function

    def models(site)
      site.data.workbench["models"]
    end

    def model(site, id)
      models(site).find { |m| m["id"] == id } || raise("no Workbench model #{id}")
    end

    def slug(text)
      text.downcase.gsub(/[^a-z0-9]+/, "-").gsub(/\A-|-\z/, "")
    end

    def page_url(id)
      "/docs/solverforge-workbench/#{id}/"
    end

    def rule_anchor(constraint)
      "rule-#{slug(constraint["name"])}"
    end

    def group_anchor(group)
      "group-#{slug(group)}"
    end

    def counts(model)
      LEVELS.to_h { |level| [level, model["constraints"].count { |c| c["level"] == level }] }
    end

    def groups(model)
      model["constraints"].group_by { |c| c["group"] }
    end

    def off_by_default?(constraint)
      constraint["description"].match?(/off unless weigh/i)
    end
  end
end
