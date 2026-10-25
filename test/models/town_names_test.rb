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

  test "spellings of one place count as the same place" do
    assert TownNames.same_place?("Bengaluru", "Bangalore")
    assert TownNames.same_place?("Ananthapur", "Anantapur")
    assert TownNames.same_place?("Rajauri", "Rajouri")
    assert TownNames.same_place?("Mahesana", "Mehsana")
    assert TownNames.same_place?("Chamrajnagar", "Chamarajanagar")
  end

  test "different towns with similar names are different places" do
    refute TownNames.same_place?("Mumbai", "Navi Mumbai")
    refute TownNames.same_place?("Bangalore", "Bangalore Rural")
    refute TownNames.same_place?("Solapur", "Kolhapur")
    refute TownNames.same_place?("Panipat", "Sonipat")
    refute TownNames.same_place?("Tiruvarur", "Tiruvallur")
    refute TownNames.same_place?("Bengaluru", "Mangalore")
  end
end
