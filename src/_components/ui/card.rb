class Ui::Card < Bridgetown::Component
  def initialize(title:, href: nil, eyebrow: nil, icon: nil)
    @title = title
    @href = href
    @eyebrow = eyebrow
    @icon = icon
  end

  def linked?
    @href && !@href.empty?
  end
end
