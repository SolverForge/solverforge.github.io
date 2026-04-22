class Shared::Navbar < Bridgetown::Component
  def initialize(metadata:, navigation:, resource:)
    @metadata = metadata
    @navigation = navigation.fetch("main")
    @resource = resource
  end

  def search_shortcut
    @resource.relative_url == "/search/" ? "/" : "Ctrl K"
  end

  def active?(item)
    url = item.fetch("url")
    return false if external?(url)
    return true if url == "/" && @resource.relative_url == "/"

    @resource.relative_url.start_with?(url)
  end

  def external?(url)
    url.start_with?("http://", "https://")
  end
end
