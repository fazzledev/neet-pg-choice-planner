require "test_helper"

class LandingTest < ActionDispatch::IntegrationTest
  test "shows the landing page at the root and links to the planner" do
    get root_path
    assert_response :success
    assert_select "a[href='#{planner_path}']", minimum: 2
    assert_match "not affiliated with the Medical Counselling Committee", response.body
  end


  test "redirects the old domain to the new one, keeping the path" do
    host! "mcc.fazzle.dev"
    get "/plan?view=institute"
    assert_redirected_to "https://neet-pg-choice-planner.fazzle.dev/plan?view=institute"

    host! "neet-pg-choices.fazzle.dev"
    get "/"
    assert_redirected_to "https://neet-pg-choice-planner.fazzle.dev/"
  end
end
