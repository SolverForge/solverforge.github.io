class Docs::SidebarItem < Bridgetown::Component
  def initialize(current_url:, item:)
    @current_url = current_url
    @item = item
  end

  def children
    @item["children"] || []
  end

  def active?
    active_item?(@item)
  end

  private

  def active_item?(item)
    href = item["href"]
    return true if @current_url == href || @current_url.start_with?(href)

    (item["children"] || []).any? { |child| active_item?(child) }
  end
end
