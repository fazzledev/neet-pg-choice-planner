require "test_helper"

class LandingTest < ActionDispatch::IntegrationTest
  test "shows the landing page at the root and links to the planner" do
    get root_path
    assert_response :success
    assert_select "a[href='#{planner_path}']", minimum: 2
    assert_match "not affiliated with the Medical Counselling Committee", response.body
  end

  test "every landing link is counted as its own click event" do
    get root_path
    links = css_select("a")
    assert links.any?
    names = links.map { _1["data-goatcounter-click"] }
    assert_equal links.size, names.compact.size, "untagged: #{links.reject { _1["data-goatcounter-click"] }.map(&:text).map(&:strip)}"
    assert_equal names.uniq, names
    assert names.all? { _1.start_with?("landing/") }, "not landing/: #{names.reject { _1.start_with?("landing/") }}"
  end

  test "shows the privacy page and links it from the landing page" do
    get privacy_path
    assert_response :success
    assert_match "hey@fazzle.dev", response.body
    get root_path
    assert_select "a[href='#{privacy_path}']"
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
