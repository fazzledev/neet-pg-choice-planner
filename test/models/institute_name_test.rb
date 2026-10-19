require "test_helper"

class InstituteNameTest < ActiveSupport::TestCase
  test "addresses shrink to the hospital and its city" do
    assert_equal "Aster Medcity, Kochi", InstituteName.shorten("Aster Medcity, Kuttisahib Road, Near Kothad Bridge, South Chittoor P. O., Cheranalloor, Kochi, Kerala-682027")
    assert_equal "Apollo Hospital, Chennai", InstituteName.shorten("Apollo Hospital, 21, Greams lane, Off Greams Rd, Thousand Lights, Chennai., Tamil Nadu-600006")
    assert_equal "Medicover hospitals, Visakhapatnam", InstituteName.shorten("Medicover hospitals (A unit of sahrudaya Healthcare Pvt. Ltd), #18-1-3, KGH Down, Maharanipeta, Visakhapatnam, Andhra Pradesh-530002")
    assert_equal "Veerangana Avantibai Lodhi Autonomous State Medical College, Etah", InstituteName.shorten("Veerangana Avantibai Lodhi Autonomous State Medical College (Formerly known as Autonomous State Medical College) Etah, Marehra Rd, Siraon-207001 Uttar Pradesh")
    assert_equal "Rohini Medicare, Warangal", InstituteName.shorten("Rohini Medicare House No. 2-5-742, Subedari, Hanamkonda Warangal - 506001 Andhra Pradesh")
    assert_equal "Mysore Medical College and Research Instt.", InstituteName.shorten("Mysore Medical College and Research Instt. (Prev.name Government Medical College), Mysore")
    assert_equal "Apollo Adlux Hospital, Ernakulam", InstituteName.shorten("Apollo Adlux Hospital ( A Unit of Adlux Medicity and Convention Centre Private Limited), Adlux Junction, Karukutty, Angamaly Ernakulam, Kerala Kerala , Kerala-683576")
    assert_equal "Ashwini Hospital, Cuttack", InstituteName.shorten("Ashwini Hospital, Plot No. 3(P), Sector - 1, CDA, Cuttack Orissa , Orissa-753014")
  end

  test "names without an address stay as they are" do
    assert_equal "Madras Medical College, Chennai", InstituteName.shorten("Madras Medical College, Chennai")
    assert_equal "Government Medical College, Kozhikode, Calicut", InstituteName.shorten("Government Medical College, Kozhikode, Calicut")
  end

  test "the catalog carries the short name and keeps the full one" do
    counselling = import_catalog
    row = JSON.parse(counselling.catalog_json)["institutes"].find { _1[1].match?(/-\d{6}\z/) }
    assert row[6].length < row[1].length
  end
end
