require "test_helper"

class TownNamesTest < ActiveSupport::TestCase
  test "old and new names of a city share one key" do
    assert_equal TownNames.key("Bangalore"), TownNames.key("Bengaluru")
    assert_equal TownNames.key("aurangabad"), TownNames.key("Chhatrapati Sambhajinagar")
  end

  test "different towns keep different keys" do
    refute_equal TownNames.key("Panipat"), TownNames.key("Sonipat")
    assert_equal "kolargoldfields", TownNames.key("Kolar Gold Fields")
  end
end
