require "application_system_test_case"

class SignInTest < ApplicationSystemTestCase
  setup do
    import_catalog
    User.create!(email: "student@example.com")
  end

  test "a student signs in with an emailed link in a real browser" do
    with_forgery_protection do
      visit new_session_path
      fill_in "Email", with: "student@example.com"
      click_on "Email me a sign-in link"
      assert_text "Check your email"
      perform_enqueued_jobs

      visit URI(ActionMailer::Base.deliveries.last.text_part.decoded[%r{https?://\S+/sign-in/\S+}]).path
      click_on "Sign in"

      assert_current_path planner_path
      assert_no_selector "#local-banner"
      assert_selector "form#sign-out", visible: :all
    end
  end
end
