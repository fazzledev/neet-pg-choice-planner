require "test_helper"

class MccResults::ClosingRanksTest < ActiveSupport::TestCase
  test "keeps the last rank allotted per choice, year, round and category" do
    Dir.mktmpdir do |dir|
      path = File.join(dir, "2025-R1.csv")
      CSV.open(path, "w") do |csv|
        csv << %w[year round rank quota institute course allotted_category candidate_category remarks]
        csv << [2025, "R1", 120, "All India", "Government Medical College, Nagpur, Maharashtra", "M.D. (GENERAL MEDICINE)", "Open", "General", "Allotted"]
        csv << [2025, "R1", 480, "All India", "Government Medical College, Nagpur, Maharashtra", "M.D. (GENERAL MEDICINE)", "Open", "OBC", "Allotted"]
        csv << [2025, "R1", 900, "All India", "Government Medical College, Nagpur, Maharashtra", "M.D. (GENERAL MEDICINE)", "OBC PwD", "OBC", "Allotted"]
        csv << [2025, "R1", 50, "Non-Resident Indian", "Government Medical College, Nagpur, Maharashtra", "M.D. (GENERAL MEDICINE)", "Open", "General", "Allotted"]
      end
      catalog = {
        "institutes" => [{ "code" => "1", "name" => "Government Medical College, Nagpur", "address" => "Nagpur, Maharashtra" }],
        "choices" => [{ "instcd" => "1", "brcd" => "GMED", "quota" => "All India" }],
      }
      result = MccResults::ClosingRanks.new(catalog:, courses: { "M.D. (GENERAL MEDICINE)" => "GMED" }, allotments: [path]).build

      assert_equal [[2025, "R1", "OBC PwD", 900], [2025, "R1", "Open", 480]], MccResults::ClosingRanks.serialize(result.ranks)["1|GMED|All India"]
      assert_equal 3, result.stats["2025-R1"][:matched]
    end
  end
end
