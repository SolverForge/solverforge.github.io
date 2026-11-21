# Reads src/_data/workbench.json: the stock models as the Workbench engine
# release describes them. Names, groups, levels and counts on the Workbench
# pages come from here; the explanations are written in the pages.
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

    def constraint(site, id, name)
      model(site, id)["constraints"].find { |c| c["name"] == name } ||
        raise("the #{id} model has no constraint #{name.inspect}")
    end

    def slug(text)
      text.downcase.gsub(/[^a-z0-9]+/, "-").gsub(/\A-|-\z/, "")
    end

    def page_url(id)
      "/docs/solverforge-workbench/#{id}/"
    end

    def constraints_url(id)
      "/docs/solverforge-workbench/#{id}/constraints/"
    end

    def data_url(id)
      "/docs/solverforge-workbench/#{id}/data/"
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
