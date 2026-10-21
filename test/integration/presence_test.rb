require "test_helper"

class PresenceTest < ActionDispatch::IntegrationTest
  TAB = "0b6f5a0e-3c1d-4c8e-9a51-3f4f1e2b7c90"

  setup do
    @counselling = import_catalog
    @admin = User.create!(email: "admin@example.com", admin: true)
    @student = User.create!(email: "student@example.com")
  end

  test "a guest tab is recorded as present" do
    post presence_path, params: { tab_id: TAB }, as: :json
    assert_response :no_content
    presence = Presence.sole
    assert_equal TAB, presence.tab_id
    assert_not presence.signed_in
  end

  test "pinging again from the same tab updates it instead of adding a row" do
    post presence_path, params: { tab_id: TAB }, as: :json
    travel 1.minute do
      post presence_path, params: { tab_id: TAB }, as: :json
    end
    assert_equal 1, Presence.count
  end

  test "a signed-in tab is recorded as signed in" do
    sign_in_as @student
    post presence_path, params: { tab_id: TAB }, as: :json
    assert Presence.sole.signed_in
  end

  test "pings are accepted without a CSRF token so tabs survive a sign-out elsewhere" do
    with_forgery_protection { post presence_path, params: { tab_id: TAB }, as: :json }
    assert_response :no_content
  end

  test "tab ids are kept out of the request log" do
    filter = ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters)
    assert_equal({ "tab_id" => "[FILTERED]" }, filter.filter("tab_id" => TAB))
  end

  test "malformed tab ids are refused" do
    post presence_path, params: { tab_id: "x" * 500 }, as: :json
    assert_response :unprocessable_content
    assert_equal 0, Presence.count
  end

  test "public pages send presence pings and admin pages do not" do
    get planner_path
    assert_select "script[src*='presence']", count: 1
    sign_in_as @admin
    get admin_stats_path
    assert_select "script[src*='presence']", count: 0
  end

  test "stats show tabs seen recently, split by signed in" do
    Presence.seen!(TAB, signed_in: false)
    Presence.seen!("1b6f5a0e-3c1d-4c8e-9a51-3f4f1e2b7c90", signed_in: true)
    travel_to 3.minutes.ago do
      Presence.seen!("2b6f5a0e-3c1d-4c8e-9a51-3f4f1e2b7c90", signed_in: false)
    end
    sign_in_as @admin
    get admin_stats_path
    assert_select "#active-now .stats tbody td", text: "1", count: 2
    assert_select "#active-now .stats tbody td:last-child", text: "2"
  end

  test "presences older than a day are expired" do
    travel_to 2.days.ago do
      Presence.seen!(TAB, signed_in: false)
    end
    assert_equal [TAB], Presence.expired.pluck(:tab_id)
  end

  private

  def with_forgery_protection
    previous = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    yield
  ensure
    ActionController::Base.allow_forgery_protection = previous
  end
end
