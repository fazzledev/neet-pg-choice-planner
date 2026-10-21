require "application_system_test_case"

class FiltersTest < ApplicationSystemTestCase
  setup { import_catalog }

  test "the first click after searching a filter list ticks the option" do
    visit planner_path
    assert_selector "#facets .facet[data-facet=speciality]", visible: :all
    click_on "Filters"

    within "#facets .facet[data-facet=speciality]" do
      search = find(".facet-search")
      search.fill_in with: search_term
      find(".facet-option .opt-label", text: speciality).click
      assert_selector ".facet-option.on", text: speciality
      assert_text "1 selected"
    end
  end

  private

  def speciality
    @speciality ||= Program.where(counselling: Counselling.current).pick(:speciality)
  end

  def search_term
    speciality.split.first.first(5).downcase
  end
end
