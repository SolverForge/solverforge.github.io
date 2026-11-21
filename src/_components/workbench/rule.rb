# The heading of one constraint on a model's constraints page. The name must
# be one the engine scores, so a typo fails the build; the level and group come
# from the engine's own description. The explanation follows in the page.
class Workbench::Rule < Bridgetown::Component
  def initialize(site:, model:, name:)
    @rule = Workbench::Data.constraint(site, model, name)
  end

  def call
    level = @rule["level"]
    off = Workbench::Data.off_by_default?(@rule) ? %( data-off="true") : ""
    %(<h3 class="wb-rule" id="#{Workbench::Data.rule_anchor(@rule)}" data-level="#{level}" data-group="#{h(@rule["group"])}"#{off}>) +
      %(#{h(@rule["name"])} <span class="wb-level wb-level--#{level}">#{level}</span></h3>)
  end

  private

  def h(text)
    CGI.escapeHTML(text.to_s)
  end
end
