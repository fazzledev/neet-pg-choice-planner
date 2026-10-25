require "test_helper"

class VerifiedPlacesTest < ActiveSupport::TestCase
  class Offline < VerifiedPlaces
    def initialize(answers:, **options)
      super(**options, log: StringIO.new)
      @answers = answers
    end

    private

    def search(params) = @answers.fetch(params[:q].split(", ").first, [])
  end

  def hit(lat, lng, state) = { "lat" => lat.to_s, "lon" => lng.to_s, "place_rank" => 16, "address" => { "state" => state } }

  def row(code, town, district, state) = { "code" => code, "town" => town, "district" => district, "state" => state }

  def places(final, answers: {}, overrides: {})
    Offline.new(final:, answers:, overrides:, cache_path: Pathname(Dir.mktmpdir).join("cache.json"))
  end

  test "spelling variants of one city share a pin labelled with the most common spelling" do
    final = [row("1", "Bangalore", "Bengaluru Urban", "Karnataka"), row("2", "Bangalore", "Bengaluru Urban", "Karnataka"), row("3", "Bengaluru", "Bengaluru Urban", "Karnataka")]
    found = places(final, answers: { "Bangalore" => [hit(12.97, 77.59, "Karnataka")] }).locations
    assert_equal [[12.97, 77.59, "Bangalore"]], found.values.uniq
  end

  test "a town spelled two ways in one state gets one pin" do
    final = [row("1", "Tiruvalla", "Pathanamthitta", "Kerala"), row("2", "Thiruvalla", "Pathanamthitta", "Kerala"), row("3", "Tiruvalla", "Pathanamthitta", "Kerala")]
    found = places(final, answers: { "Tiruvalla" => [hit(9.38, 76.57, "Kerala")] }).locations
    assert_equal [[9.38, 76.57, "Tiruvalla"]], found.values.uniq
  end

  test "all of Delhi is one pin" do
    final = [row("1", "Delhi", "South Delhi", "Delhi"), row("2", "Delhi", "East Delhi", "Delhi")]
    found = places(final, answers: { "Delhi" => [hit(28.61, 77.21, "Delhi")] }).locations
    assert_equal 1, found.values.uniq.size
  end

  test "hand-checked coordinates win over the lookup" do
    final = [row("1", "Nanded", "Nanded", "Maharashtra")]
    subject = places(final, answers: { "Nanded" => [hit(20.74, 79.78, "Maharashtra")] }, overrides: { "Nanded|Nanded|Maharashtra" => { "at" => [19.1383, 77.321] } })
    assert_equal [19.1383, 77.321, "Nanded"], subject.locations["1"]
    assert_empty subject.unused_overrides
  end

  test "a match in another state is ignored and the town is flagged" do
    final = [row("1", "Srinagar", "Pauri Garhwal", "Uttarakhand")]
    subject = places(final, answers: { "Srinagar" => [hit(34.08, 74.8, "Jammu and Kashmir")] })
    assert_nil subject.locations["1"]
    assert_equal "not found", subject.flags.first[:problem]
  end
end
