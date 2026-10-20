require "test_helper"

class AnalyticsTest < ActionDispatch::IntegrationTest
  setup do
    @counselling = import_catalog
    @admin = User.create!(email: "admin@example.com", admin: true)
    @student = User.create!(email: "student@example.com")
    Rails.configuration.x.goatcounter_url = "https://stats.example.com"
  end

  teardown { Rails.configuration.x.goatcounter_url = nil }

  test "guests on the planner are counted on their own path" do
    get planner_path
    assert_equal "/plan/guest", goatcounter_settings["path"]
    assert_equal "https://stats.example.com/count", goatcounter_script["data-goatcounter"]
  end

  test "signed-in planner views are counted on the plain path" do
    sign_in_as @student
    get planner_path
    assert_equal "/plan", goatcounter_settings["path"]
  end

  test "sign-in links never send their token" do
    get sign_in_link_path(@student.generate_token_for(:sign_in))
    assert_equal "/sign-in/link", goatcounter_settings["path"]
  end

  test "sign-in links are passed on as a referrer only to this site" do
    get sign_in_link_path(@student.generate_token_for(:sign_in))
    assert_equal "same-origin", response.headers["Referrer-Policy"]
  end

  test "the page after a sign-in link is not given the link as its referrer" do
    token = @student.generate_token_for(:sign_in)
    post sign_in_link_path(token)
    assert_redirected_to planner_url
    assert_equal "no-referrer", response.headers["Referrer-Policy"]
    post sign_in_link_path(token)
    assert_redirected_to new_session_path
    assert_equal "no-referrer", response.headers["Referrer-Policy"]
  end

  test "admin pages are not counted" do
    sign_in_as @admin
    get admin_stats_path
    assert_response :success
    assert_select "script[data-goatcounter]", count: 0
  end

  test "OAuth pages are not counted" do
    sign_in_as @student
    get oauth_authorization_path(client_id: "unknown", redirect_uri: "https://example.com/cb")
    assert_select "html"
    assert_select "script[data-goatcounter]", count: 0
  end

  test "nothing is counted without a GoatCounter url" do
    Rails.configuration.x.goatcounter_url = nil
    get planner_path
    assert_select "script[data-goatcounter]", count: 0
  end

  test "stats count signed-in people and plan changes" do
    sign_in_as @student
    list = @student.choice_list_for(@counselling)
    list.replace_picks!([{ "choice_id" => @counselling.choices.first.id }])
    delete session_path
    sign_in_as @admin
    get admin_stats_path
    assert_select ".admin-head .muted", text: /2 people signed in at least once · 1 plan with choices/
    assert_select ".stats tbody tr:nth-child(3) td", text: "1", count: 2
  end

  test "only admins see stats" do
    sign_in_as @student
    get admin_stats_path
    assert_response :forbidden
  end

  private

  def goatcounter_script
    css_select("script[data-goatcounter]").sole
  end

  def goatcounter_settings
    JSON.parse(goatcounter_script["data-goatcounter-settings"])
  end
end
