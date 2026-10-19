require "test_helper"

class InstituteContactTest < ActiveSupport::TestCase
  test "the research file imports idempotently and rides along in the catalog" do
    counselling = import_catalog
    2.times { InstituteContact.import(Rails.root.join("data/dnb_contacts.json")) }
    assert_equal 17, InstituteContact.count
    lisie = JSON.parse(counselling.catalog_json)["contacts"]["700862"]
    assert_equal "high", lisie["confidence"]
    assert_includes lisie["sources"].first, "lisiehospital.org"
    assert_equal "2026-10-19", lisie["researched_on"]
  end
end
