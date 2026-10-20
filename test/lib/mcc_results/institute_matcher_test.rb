require "test_helper"

class MccResults::InstituteMatcherTest < ActiveSupport::TestCase
  INSTITUTES = [
    { "code" => "1", "name" => "Government Medical College, Nagpur", "address" => "Government Medical College, Nagpur" },
    { "code" => "2", "name" => "Indira Gandhi Government Medical College, Nagpur", "address" => "Central Avenue Road, Nagpur, Maharashtra" },
    { "code" => "3", "name" => "Gandhi Medical College, Bhopal", "address" => "Gandhi Medical College, Bhopal" },
    { "code" => "4", "name" => "Gandhi Medical College, Secunderabad", "address" => "GANDHI MEDICAL COLLEGE, SECUNDERABAD, HYDERABAD" },
    { "code" => "5", "name" => "Autonomous State Medical College, Tiloi, Amethi", "address" => "Autonomous State Medical College, Amethi, Uttar Pradesh" },
    { "code" => "6", "name" => "Autonomous State Medical College, Etah", "address" => "Etah, Uttar Pradesh" },
  ].freeze

  setup { @matcher = MccResults::InstituteMatcher.new(INSTITUTES) }

  test "matches a college by its own name and city, even with words split by the PDF" do
    match = @matcher.match("GOVER NMENT MEDICA L COLLEG E, NAGPU R,Government Medical College, Nagpur, Maharashtra, 440003", %w[1 2])
    assert_equal "1", match.code
  end

  test "does not mistake a longer name that contains a shorter one" do
    match = @matcher.match("Indira Gandhi Government Medical College, Nagpur,Central Avenue Road, Maharashtra, 440018", %w[1 2])
    assert_equal "2", match.code
  end

  test "never matches a college in another state" do
    match = @matcher.match("GANDHI MEDICAL COLLEGE,GANDHI MEDICAL COLLEGE, Telangana, 500003", %w[3 4])
    assert_not_equal "3", match&.code
  end

  test "leaves a name shared by several colleges unmatched instead of guessing" do
    assert_nil @matcher.match("AUTONOMOUS STATE MEDICAL COLLEGE, ,RAJARSHI DASHRATH AUTONOMOUS STATE MEDICAL COLLEGE AYODHYA, Uttar Pradesh, 224133", %w[5 6])
  end
end
