class Docs::Sidebar < Bridgetown::Component
  def initialize(current_url:, items:, title:)
    @current_url = current_url
    @items = items
    @title = title
  end
end
