class Oauth::TokensController < ActionController::API
  rate_limit to: 60, within: 1.minute, with: -> { oauth_error("slow_down", status: :too_many_requests) }

  def create
    response.headers["Cache-Control"] = "no-store"
    client = OauthClient.find_by(client_id: client_id) or return oauth_error("invalid_client", status: :unauthorized)

    tokens =
      case params[:grant_type]
      when "authorization_code"
        OauthGrant.redeem_code(params[:code].to_s, client: client, redirect_uri: params[:redirect_uri].presence, code_verifier: params[:code_verifier])
      when "refresh_token"
        OauthGrant.refresh(params[:refresh_token].to_s, client: client)
      else
        return oauth_error("unsupported_grant_type")
      end

    tokens ? render(json: tokens) : oauth_error("invalid_grant")
  end

  private

  def client_id
    params[:client_id].presence || (ActionController::HttpAuthentication::Basic.user_name_and_password(request).first if request.authorization.to_s.start_with?("Basic "))
  end

  def oauth_error(code, status: :bad_request)
    render json: { error: code }, status: status
  end
end
