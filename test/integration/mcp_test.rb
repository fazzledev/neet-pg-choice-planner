require "test_helper"

class McpTest < ActionDispatch::IntegrationTest
  REDIRECT_URI = "https://chatgpt.com/connector_platform_oauth_redirect".freeze

  setup do
    @counselling = import_catalog
    @student = User.create!(email: "student@example.com")
    @ids = @counselling.choices.order(:sr).limit(4).pluck(:id)
    @verifier = SecureRandom.urlsafe_base64(48)
  end

  test "publishes OAuth discovery for the MCP endpoint" do
    get "/.well-known/oauth-protected-resource/mcp"
    assert_equal "http://www.example.com/mcp", response.parsed_body["resource"]
    assert_equal ["http://www.example.com"], response.parsed_body["authorization_servers"]

    get "/.well-known/oauth-authorization-server"
    metadata = response.parsed_body
    assert_equal "http://www.example.com", metadata["issuer"]
    assert_equal ["S256"], metadata["code_challenge_methods_supported"]
    assert_equal ["none"], metadata["token_endpoint_auth_methods_supported"]
    assert_equal "http://www.example.com/oauth/register", metadata["registration_endpoint"]
  end

  test "asks for a token with a challenge that points at the metadata" do
    rpc "tools/list"
    assert_response :unauthorized
    assert_includes response.headers["WWW-Authenticate"], %(resource_metadata="http://www.example.com/.well-known/oauth-protected-resource/mcp")

    rpc "tools/list", token: "nope"
    assert_response :unauthorized
    assert_includes response.headers["WWW-Authenticate"], %(error="invalid_token")
  end

  test "a student connects, signs in by email, allows, and the assistant edits the plan" do
    client_id = register
    authorize_params = authorize_query(client_id)

    get "/oauth/authorize", params: authorize_params
    assert_redirected_to new_session_path

    post sign_in_link_path(@student.generate_token_for(:sign_in))
    assert_redirected_to "http://www.example.com/oauth/authorize?#{URI.encode_www_form(authorize_params)}"
    follow_redirect!
    assert_response :success
    assert_select "h1", "Allow ChatGPT?"
    assert_select "strong", "chatgpt.com"

    post "/oauth/authorize", params: authorize_params.merge(decision: "allow")
    callback = URI.parse(response.location)
    query = Rack::Utils.parse_query(callback.query)
    assert_equal "chatgpt.com", callback.host
    assert_equal "xyz", query["state"]
    assert_equal "http://www.example.com", query["iss"]

    tokens = exchange(client_id, query["code"])
    assert_equal "Bearer", tokens["token_type"]
    assert_equal 3600, tokens["expires_in"]

    rpc "initialize", { protocolVersion: "2025-06-18", capabilities: {}, clientInfo: { name: "test", version: "1" } }, token: tokens["access_token"]
    assert_equal "2025-06-18", result["protocolVersion"]
    assert_includes result["instructions"], "MCC"

    rpc "notifications/initialized", nil, token: tokens["access_token"], notification: true
    assert_response :accepted

    rpc "tools/list", token: tokens["access_token"]
    names = result["tools"].map { _1["name"] }
    assert_includes names, "search_choices"
    assert result["tools"].all? { _1["securitySchemes"] == [{ "type" => "oauth2", "scopes" => ["plan"] }] }

    call "add_to_plan", { choice_ids: @ids.first(3) }, token: tokens["access_token"]
    assert_equal [1, 2, 3], result["structuredContent"]["changed"].map { _1["position"] }

    call "get_plan", {}, token: tokens["access_token"]
    plan = result["structuredContent"]
    assert_equal @ids.first(3), plan["picks"].map { _1["choice_id"] }
    assert_equal 1, plan["revision"]

    list = @student.choice_list_for(@counselling)
    assert_equal @student.oauth_grants.sole.session_id, list.snapshots.sole.session_id

    post "/oauth/token", params: { grant_type: "refresh_token", refresh_token: tokens["refresh_token"], client_id: client_id }
    refreshed = response.parsed_body
    assert_response :success
    assert_not_equal tokens["access_token"], refreshed["access_token"]

    rpc "tools/list", token: tokens["access_token"]
    assert_response :unauthorized
    rpc "tools/list", token: refreshed["access_token"]
    assert_response :success

    get connect_path
    assert_select ".connections li", 1
    delete connection_path(@student.oauth_grants.sole)
    assert_redirected_to connect_path
    rpc "tools/list", token: refreshed["access_token"]
    assert_response :unauthorized
    assert_equal 0, @student.sessions.where(user_agent: "ChatGPT (connector)").count
  end

  test "a refresh retried within seconds still works, but an old refresh token later revokes the grant" do
    client_id = register
    tokens = exchange(client_id, allow(client_id))
    refresh = ->(token) { post "/oauth/token", params: { grant_type: "refresh_token", refresh_token: token, client_id: client_id }; response.parsed_body }

    first = refresh.(tokens["refresh_token"])
    retried = refresh.(tokens["refresh_token"])
    assert retried["access_token"]
    assert_equal "invalid_grant", refresh.(first["refresh_token"])["error"]

    travel 1.minute do
      assert_equal "invalid_grant", refresh.(tokens["refresh_token"])["error"]
      assert_equal 0, OauthGrant.count
      assert_equal "invalid_grant", refresh.(retried["refresh_token"])["error"]
    end
  end

  test "the cleanup keeps clients that ever connected, so a student can reconnect after disconnecting" do
    client_id = register
    unused_id = register
    exchange(client_id, allow(client_id))
    delete connection_path(OauthGrant.sole)

    travel 2.days do
      OauthGrant.stale.includes(:session).find_each(&:disconnect!)
      OauthClient.unclaimed.destroy_all
      assert_not OauthClient.exists?(client_id: unused_id)
      get "/oauth/authorize", params: authorize_query(client_id)
      assert_response :success
    end
  end

  test "an unexpected error comes back as a JSON-RPC internal error" do
    token = connect
    Mcp::Tools.class_eval { alias_method :original_get_plan, :get_plan; define_method(:get_plan) { |_| raise KeyError, "boom" } }
    rpc "tools/call", { name: "get_plan", arguments: {} }, token: token
    assert_response :internal_server_error
    assert_equal(-32603, response.parsed_body["error"]["code"])
    assert_equal 1, response.parsed_body["id"]
  ensure
    Mcp::Tools.class_eval { alias_method :get_plan, :original_get_plan; remove_method :original_get_plan }
  end

  test "denying sends access_denied back to the app" do
    client_id = register
    sign_in_as @student
    post "/oauth/authorize", params: authorize_query(client_id).merge(decision: "deny")
    assert_equal "access_denied", Rack::Utils.parse_query(URI.parse(response.location).query)["error"]
    assert_equal 0, OauthGrant.count
  end

  test "a code needs the right verifier and a reused code revokes the grant" do
    client_id = register
    code = allow(client_id)

    post "/oauth/token", params: { grant_type: "authorization_code", code: code, client_id: client_id, redirect_uri: REDIRECT_URI, code_verifier: SecureRandom.urlsafe_base64(48) }
    assert_equal "invalid_grant", response.parsed_body["error"]

    tokens = exchange(client_id, code)
    post "/oauth/token", params: { grant_type: "authorization_code", code: code, client_id: client_id, redirect_uri: REDIRECT_URI, code_verifier: @verifier }
    assert_equal "invalid_grant", response.parsed_body["error"]
    rpc "tools/list", token: tokens["access_token"]
    assert_response :unauthorized
  end

  test "codes expire" do
    client_id = register
    code = allow(client_id)
    travel 6.minutes do
      post "/oauth/token", params: { grant_type: "authorization_code", code: code, client_id: client_id, redirect_uri: REDIRECT_URI, code_verifier: @verifier }
      assert_equal "invalid_grant", response.parsed_body["error"]
    end
  end

  test "registration rejects unsafe redirect URIs and authorize refuses unregistered ones" do
    post "/oauth/register", params: { redirect_uris: ["http://evil.example/cb"] }.to_json, headers: { "Content-Type" => "application/json" }
    assert_response :bad_request
    post "/oauth/register", params: { redirect_uris: ["javascript:alert(1)"] }.to_json, headers: { "Content-Type" => "application/json" }
    assert_response :bad_request
    post "/oauth/register", params: { redirect_uris: ["myapp:callback"] }.to_json, headers: { "Content-Type" => "application/json" }
    assert_response :bad_request

    client_id = register(uris: ["http://localhost:33418/callback"])
    sign_in_as @student
    get "/oauth/authorize", params: authorize_query(client_id).merge(redirect_uri: "https://elsewhere.example/cb")
    assert_response :bad_request
    get "/oauth/authorize", params: authorize_query(client_id).merge(redirect_uri: "http://localhost:51234/callback")
    assert_response :success
    get "/oauth/authorize", params: authorize_query(client_id).merge(redirect_uri: "http://localhost:51234/callback").except(:code_challenge)
    assert_equal "invalid_request", Rack::Utils.parse_query(URI.parse(response.location).query)["error"]
  end

  test "modern clients discover the server statelessly and must mirror headers" do
    token = connect

    modern "server/discover", {}, token: token
    assert_response :success
    assert_equal "complete", result["resultType"]
    assert_includes result["supportedVersions"], "2026-07-28"
    assert_equal "neet-pg-choice-planner", result["_meta"]["io.modelcontextprotocol/serverInfo"]["name"]

    modern "tools/call", { name: "list_filters", arguments: {} }, token: token, mcp_name: "=?base64?#{Base64.strict_encode64("list_filters")}?="
    assert_includes result["structuredContent"]["quotas"], "All India"

    modern "tools/call", { name: "list_filters", arguments: {} }, token: token, mcp_name: "get_plan"
    assert_response :bad_request
    assert_equal(-32020, response.parsed_body["error"]["code"])

    modern "tools/list", {}, token: token, version: "2027-01-01"
    assert_response :bad_request
    assert_equal(-32022, response.parsed_body["error"]["code"])

    modern "prompts/list", {}, token: token
    assert_response :not_found
    assert_equal(-32601, response.parsed_body["error"]["code"])
  end

  test "rejects browsers from other origins and non-POST requests" do
    token = connect
    rpc "tools/list", token: token, headers: { "Origin" => "https://evil.example" }
    assert_response :forbidden
    get "/mcp"
    assert_response :method_not_allowed
  end

  test "search, institute and every plan edit" do
    token = connect

    call "search_choices", { query: "orthopaedics", quota: ["all india"], limit: 2 }, token: token
    search = result["structuredContent"]
    assert_equal 2, search["results"].size
    assert search["results"].all? { _1["quota"] == "All India" && _1["speciality"].match?(/ortho/i) }
    assert_equal 2, search["next_offset"]

    code = search["results"].first["institute_code"]
    call "get_institute", { code: code }, token: token
    assert_equal code, result["structuredContent"]["institute_code"]
    assert result["structuredContent"]["choices"].any?

    call "add_to_plan", { choice_ids: @ids.first(2) }, token: token
    call "add_to_plan", { choice_ids: [@ids[2], @ids[0]], position: 1 }, token: token
    assert_equal [@ids[0]], result["structuredContent"]["already_in_plan"]
    assert_equal [@ids[2], @ids[0], @ids[1]], plan_ids

    call "move_in_plan", { choice_ids: [@ids[2]], position: 3 }, token: token
    assert_equal [@ids[0], @ids[1], @ids[2]], plan_ids

    call "set_note", { choice_id: @ids[1], note: "Ask about stipend" }, token: token
    call "replace_plan", { choice_ids: [@ids[1], @ids[3]] }, token: token
    assert_equal({ "added" => 1, "removed" => 2 }, result["structuredContent"].slice("added", "removed"))
    call "get_plan", {}, token: token
    assert_equal "Ask about stipend", result["structuredContent"]["picks"].first["note"]

    call "remove_from_plan", { choice_ids: [@ids[3]] }, token: token
    assert_equal [@ids[1]], plan_ids

    call "replace_plan", { choice_ids: [], base_revision: 0 }, token: token
    assert result["isError"]
    assert_includes result["content"].first["text"], "get_plan"

    call "add_to_plan", { choice_ids: [999_999] }, token: token
    assert result["isError"]
    call "set_note", { choice_id: @ids[3], note: "x" }, token: token
    assert result["isError"]

    call "search_choices", { query: "orthopaedics", exclude_planned: true, limit: 100 }, token: token
    assert result["structuredContent"]["results"].none? { _1["plan_position"] }

    call "get_profile", {}, token: token
    assert_equal "student@example.com", result["structuredContent"]["email"]
    assert_match(/\A\h{32}\z/, result["structuredContent"]["id"])
  end

  private

  def register(uris: [REDIRECT_URI])
    post "/oauth/register", params: { client_name: "ChatGPT", redirect_uris: uris, token_endpoint_auth_method: "none" }.to_json, headers: { "Content-Type" => "application/json" }
    assert_response :created
    response.parsed_body["client_id"]
  end

  def authorize_query(client_id)
    challenge = Base64.urlsafe_encode64(Digest::SHA256.digest(@verifier), padding: false)
    { response_type: "code", client_id: client_id, redirect_uri: REDIRECT_URI, code_challenge: challenge, code_challenge_method: "S256",
      state: "xyz", scope: "plan", resource: "http://www.example.com/mcp" }
  end

  def allow(client_id)
    sign_in_as @student unless @signed_in
    @signed_in = true
    post "/oauth/authorize", params: authorize_query(client_id).merge(decision: "allow")
    Rack::Utils.parse_query(URI.parse(response.location).query)["code"]
  end

  def exchange(client_id, code)
    post "/oauth/token", params: { grant_type: "authorization_code", code: code, client_id: client_id, redirect_uri: REDIRECT_URI, code_verifier: @verifier }
    assert_response :success
    response.parsed_body
  end

  def connect
    client_id = register
    exchange(client_id, allow(client_id))["access_token"]
  end

  def rpc(method, params = nil, token: nil, notification: false, headers: {})
    body = { jsonrpc: "2.0", method: method, params: params }.compact
    body[:id] = 1 unless notification
    headers = headers.merge("Content-Type" => "application/json", "Accept" => "application/json, text/event-stream")
    headers["Authorization"] = "Bearer #{token}" if token
    post "/mcp", params: body.to_json, headers: headers
  end

  def modern(method, params, token:, version: "2026-07-28", mcp_name: params[:name])
    meta = { "io.modelcontextprotocol/protocolVersion" => version, "io.modelcontextprotocol/clientCapabilities" => {} }
    headers = { "MCP-Protocol-Version" => version, "Mcp-Method" => method, "Mcp-Name" => mcp_name }.compact
    rpc method, params.merge(_meta: meta), token: token, headers: headers
  end

  def call(name, arguments, token:)
    rpc "tools/call", { name: name, arguments: arguments }, token: token
    assert_response :success
  end

  def result
    response.parsed_body["result"]
  end

  def plan_ids
    @student.choice_list_for(@counselling).picks.reload.pluck(:choice_id)
  end
end
