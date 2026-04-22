class Shared::Footer < Bridgetown::Component
  def initialize(metadata:, navigation:)
    @metadata = metadata
    @navigation = navigation.fetch("footer")
  end
end
