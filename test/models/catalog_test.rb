require "test_helper"

class CatalogTest < ActiveSupport::TestCase
  test "import classifies programs and locates states, and re-import is idempotent" do
    counselling = import_catalog
    import_catalog
    assert_equal 34, counselling.choices.count
    ortho = counselling.programs.where(speciality: "Orthopaedics").pluck(:course).sort
    assert_equal ["DNB", "Diploma", "MS"], ortho
    assert counselling.institutes.where(state: nil).none?
  end

  test "program names split into course and speciality" do
    assert_equal ["MS", "Orthopaedics"], ProgramName.classify("M.S. Orthopaedics")
    assert_equal ["DNB 6-yr", "Neurosurgery"], ProgramName.classify("(NBEMS) NEURO SURGERY (DIRECT 6 YEARS COURSE)")
    assert_equal ["Diploma", "Orthopaedics"], ProgramName.classify("Diploma in Orthopaedics (D.Orth.)")
    assert_equal ["MD", "Health Administration"], ProgramName.classify("M.D.(COMMUNITY HEALTH ADMN.)")
  end

  test "ambiguous places are flagged" do
    assert_equal ["Kerala", false], Places.locate("Aster Medcity, Kochi, Kerala-682027")
    assert_equal ["Jammu and Kashmir", true], Places.locate("Government Medical College, Srinagar")
  end
end
