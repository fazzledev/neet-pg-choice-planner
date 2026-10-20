class McpController < ActionController::API
  before_action :reject_foreign_origin
  before_action :authenticate_bearer, only: :create

  def create
    message = JSON.parse(request.raw_post)
    status, body = Mcp::Server.new(grant: @grant, headers: request.headers).handle(message)
    body ? render(json: body, status: status) : head(status)
  rescue JSON::ParserError
    render json: { jsonrpc: "2.0", id: nil, error: { code: -32700, message: "Parse error" } }, status: :bad_request
  rescue StandardError => error
    Rails.error.report(error)
    render json: { jsonrpc: "2.0", id: message.is_a?(Hash) ? message["id"] : nil, error: { code: -32603, message: "Internal error" } }, status: :internal_server_error
  end

  def not_allowed
    response.headers["Allow"] = "POST"
    head :method_not_allowed
  end

  private

  def reject_foreign_origin
    origin = request.headers["Origin"]
    head :forbidden if origin.present? && origin != request.base_url
  end

  def authenticate_bearer
    token = request.authorization.to_s[/\ABearer\s+(\S+)\z/i, 1]
    @grant = OauthGrant.authenticate(token)
    return Current.session = @grant.session if @grant

    challenge = %(Bearer resource_metadata="#{OauthMetadata.resource_metadata_url(request.base_url)}", scope="#{OauthGrant::SCOPE}")
    challenge += %(, error="invalid_token", error_description="Sign in again") if token
    response.headers["WWW-Authenticate"] = challenge
    render json: { error: token ? "invalid_token" : "unauthorized" }, status: :unauthorized
  end
end
