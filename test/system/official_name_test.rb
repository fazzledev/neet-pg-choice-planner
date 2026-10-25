require "application_system_test_case"

class OfficialNameTest < ApplicationSystemTestCase
  setup { import_catalog }

  test "the info button shows the official name and address and keeps it open while the plan changes" do
    visit planner_path
    card = find("#results li.result", match: :first)
    official = Institute.find_by!(code: Choice.find(card["data-id"]).institute.code).name

    within(card) do
      assert_no_text official
      find(".info-btn").click
      assert_selector ".info-btn[aria-expanded=true]"
      assert_text official
      find(".r-add").click
    end

    within("#picks") do
      assert_selector ".info-btn[aria-expanded=true]"
      assert_text official
      assert_no_selector "li.pick.open"
    end
  end
end
