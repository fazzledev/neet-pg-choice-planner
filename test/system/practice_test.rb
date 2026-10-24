require "application_system_test_case"

class PracticeTest < ApplicationSystemTestCase
  setup { import_catalog }

  test "adds, reorders and removes choices like MCC's choice filling page" do
    visit practice_path
    assert_text "This is not MCC"
    assert_selector "#avlChoiceContainer input.aChoice", minimum: 3

    first, second = available_institute_codes.first(2)
    add first
    add second
    assert_filled_order [first, second]

    within(filled_row(second)) { find("input.Up").click }
    assert_filled_order [second, first]

    within(filled_row(first)) { find("input.fChoice").click }
    assert_filled_order [second]

    visit practice_path
    assert_filled_order [second]
  end

  test "locking takes two presses and start over unlocks" do
    visit practice_path
    add available_institute_codes.first

    click_on "Lock choices"
    assert_text "Press Lock choices again"
    assert_selector "#filledChoiceContainer input.fChoice"

    click_on "Lock choices"
    assert_text "Locked."
    assert_no_selector "#filledChoiceContainer input.fChoice"
    assert_no_selector "#avlChoiceContainer input.aChoice"

    click_on "Start over"
    assert_text "Started over"
    assert_text "No choices filled yet"
    assert_selector "#avlChoiceContainer input.aChoice", minimum: 1
  end

  private

  def available_institute_codes
    all("#avlChoiceContainer tbody tr").first(20).map { |row| row.find("td", match: :first).text }.uniq
  end

  def add(code)
    count = all("#filledChoiceContainer tbody tr[data-choice-id]").size
    find("#avlChoiceContainer tbody tr", text: code, match: :first).find("input.aChoice").click
    assert_selector "#filledChoiceContainer tbody tr[data-choice-id]", count: count + 1
  end

  def filled_row(code)
    find("#filledChoiceContainer tbody tr[data-choice-id]", text: code)
  end

  def filled_institute_codes
    all("#filledChoiceContainer tbody tr[data-choice-id]").map { |row| row.find("td", match: :first).text }
  end

  def assert_filled_order(expected)
    assert_equal expected, filled_order_once_it_matches(expected)
  end

  def filled_order_once_it_matches(expected)
    actual = nil
    page.document.synchronize do
      actual = filled_institute_codes
      raise Capybara::ExpectationNotMet unless actual == expected
    end
    actual
  rescue Capybara::ExpectationNotMet
    actual
  end
end
