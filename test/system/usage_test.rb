require "application_system_test_case"

class UsageTest < ApplicationSystemTestCase
  setup { import_catalog }

  test "guest actions wait in an outbox until GoatCounter can take them" do
    visit planner_path
    first(".r-add").click
    assert_selector "#picks li"
    find("#q").fill_in with: "a"

    assert_includes outbox, "guest/searched-catalog"
    assert_includes outbox, "guest/edited-plan"

    page.execute_script(<<~JS)
      window.sent = []
      window.goatcounter = { count: (vars) => window.sent.push(vars.path) }
      window.dispatchEvent(new Event("online"))
    JS
    assert_empty outbox
    assert_includes page.evaluate_script("window.sent"), "guest/edited-plan"
  end

  test "leaving the page after an edit counts the plan size in a band" do
    visit planner_path
    first(".r-add").click
    assert_selector "#picks li"

    page.execute_script(<<~JS)
      Object.defineProperty(document, "visibilityState", { value: "hidden", configurable: true })
      document.dispatchEvent(new Event("visibilitychange"))
    JS
    assert_includes outbox, "guest/plan-size/1-10"

    page.execute_script(<<~JS)
      Object.defineProperty(document, "visibilityState", { value: "visible", configurable: true })
      document.dispatchEvent(new Event("visibilitychange"))
    JS
    all(".r-add").last.click
    page.execute_script(<<~JS)
      Object.defineProperty(document, "visibilityState", { value: "hidden", configurable: true })
      document.dispatchEvent(new Event("visibilitychange"))
    JS
    assert_equal 1, outbox.count { |name| name.include?("plan-size") }
  end

  test "only well-formed extension counts are accepted from the extension" do
    visit planner_path
    assert_selector "#picks", visible: :all
    page.execute_script(<<~JS)
      document.dispatchEvent(new CustomEvent("choice-filler:usage", {
        detail: JSON.stringify(["extension/filled-mcc/11-50", "extension/filled-mcc/201-plus", "extension/read-mcc", "guest/edited-plan", "extension/../x", "https://evil.example", 7])
      }))
      document.dispatchEvent(new CustomEvent("choice-filler:usage", { detail: JSON.stringify({ not: "a list" }) }))
    JS
    assert_equal ["extension/filled-mcc/11-50", "extension/filled-mcc/201-plus", "extension/read-mcc"], outbox.grep(%r{\A(extension|guest/edited)})
  end

  test "filters are counted by name, never by the value chosen" do
    visit planner_path
    assert_selector "#facets .facet[data-facet=speciality]", visible: :all
    click_on "Filters"
    option = first("#facets .facet[data-facet=speciality] .facet-option .opt-label")
    value = option.text
    option.click

    assert_includes outbox, "guest/filter/speciality"
    assert outbox.none? { |name| name.downcase.include?(value.downcase) }
  end

  test "opening a saved plan counts its size in a band" do
    visit planner_path
    first(".r-add").click
    assert_selector "#picks li"

    visit planner_path
    assert_selector "#picks li"
    assert_includes outbox, "guest/saved-plan-size/1-10"
  end

  private

  def outbox
    page.evaluate_script(%(JSON.parse(localStorage.getItem("planner:usage-outbox") || "[]")))
  end
end
