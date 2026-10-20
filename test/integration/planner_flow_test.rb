require "test_helper"

class PlannerFlowTest < ActionDispatch::IntegrationTest
  setup do
    @counselling = import_catalog
    @student = User.create!(email: "student@example.com")
    @ids = @counselling.choices.order(:sr).limit(3).pluck(:id)
  end

  test "anyone can open the planner and the catalog without signing in" do
    get planner_path
    assert_response :success
    assert_select "#local-banner"
    get catalog_path(@counselling)
    assert_response :success
    assert_equal 34, response.parsed_body["choices"].size
  end

  test "sign-in links work once" do
    token = @student.generate_token_for(:sign_in)
    get sign_in_link_path(token)
    assert_response :success
    assert_nil @student.reload.last_signed_in_at
    post sign_in_link_path(token)
    assert_redirected_to planner_url
    delete session_path
    post sign_in_link_path(token)
    assert_redirected_to new_session_path
  end

  test "requesting a link creates the account and emails it without revealing anything" do
    assert_enqueued_emails 1 do
      post session_path, params: { email: "New@Example.com " }
    end
    assert_redirected_to new_session_path(sent: 1)
    assert User.exists?(email: "new@example.com")
    assert_no_enqueued_emails do
      post session_path, params: { email: "new@example.com" }
    end
    get admin_users_path
    assert_redirected_to new_session_path
  end

  test "an existing user gets a sign-in link" do
    assert_enqueued_emails 1 do
      post session_path, params: { email: " Student@Example.com" }
    end
    assert_equal 1, User.where(email: "student@example.com").count
  end

  test "a bad email sends nothing and reveals nothing" do
    assert_no_enqueued_emails do
      post session_path, params: { email: "not-an-email" }
    end
    assert_redirected_to new_session_path(sent: 1)
  end

  test "invites last a week" do
    token = @student.generate_token_for(:invite)
    travel 3.days do
      post sign_in_link_path(token)
      assert_redirected_to planner_url
    end
  end

  test "a save without a base revision is treated as a conflict" do
    sign_in_as @student
    list = @student.choice_list_for(@counselling)
    put list_picks_path(list), params: { picks: [] }, as: :json
    assert_response :conflict
  end

  test "a signed-in student saves their list and gets a conflict on a stale base" do
    sign_in_as @student
    get planner_path
    list = @student.choice_lists.sole
    put list_picks_path(list), params: { base: 0, picks: @ids.map { { choice_id: _1, note: "" } } }, as: :json
    assert_response :success
    assert_equal 1, response.parsed_body["revision"]
    put list_picks_path(list), params: { base: 0, picks: [] }, as: :json
    assert_response :conflict
  end

  test "a save tells the student's other open tabs the new revision" do
    sign_in_as @student
    get planner_path
    list = @student.choice_lists.sole
    assert_select "turbo-cable-stream-source[signed-stream-name=?]", Turbo::StreamsChannel.signed_stream_name(list)

    streams = capture_turbo_stream_broadcasts(list) do
      put list_picks_path(list), params: { base: 0, picks: @ids.map { { choice_id: _1, note: "" } } }, as: :json
    end
    assert_equal [["plan_changed", "1"]], streams.map { [_1["action"], _1["revision"]] }

    conflicting = capture_turbo_stream_broadcasts(list) do
      put list_picks_path(list), params: { base: 0, picks: [] }, as: :json
    end
    assert_response :conflict
    assert_empty conflicting
  end

  test "the planner subscribes to nothing without an account" do
    get planner_path
    assert_select "turbo-cable-stream-source", 0
  end

  test "students cannot see each other's lists but admins can" do
    other = User.create!(email: "other@example.com").choice_list_for(@counselling)
    sign_in_as @student
    get list_picks_path(other), as: :json
    assert_response :not_found

    admin = User.create!(email: "admin@example.com", admin: true)
    sign_in_as admin
    get list_picks_path(other), as: :json
    assert_response :success
    get admin_users_path
    assert_response :success
  end

  test "list endpoints require sign-in" do
    list = @student.choice_list_for(@counselling)
    get list_picks_path(list), as: :json
    assert_response :unauthorized
  end

  test "only known labels name a history snapshot" do
    sign_in_as @student
    list = @student.choice_list_for(@counselling)

    put list_picks_path(list), params: { base: 0, picks: [{ choice_id: @ids[0], note: "" }], label: "anything goes" }, as: :json
    assert_response :success
    assert_empty list.snapshots.where.not(label: nil)

    put list_picks_path(list), params: { base: 1, picks: [{ choice_id: @ids[1], note: "" }], label: "Imported from MCC" }, as: :json
    assert_response :success
    assert_equal ["Imported from MCC"], list.snapshots.where.not(label: nil).pluck(:label)
  end
end
