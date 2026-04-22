class Ui::Callout < Bridgetown::Component
  def initialize(title: nil, variant: "info")
    @title = title
    @variant = variant
  end

  def title?
    @title && !@title.empty?
  end
end
