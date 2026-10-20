class Oauth::AuthorizationsController < ApplicationController
  before_action :load_authorization_request, prepend: true

  def new
  end

  def create
    if params[:decision] == "allow"
      code = OauthGrant.start(client: @client, user: current_user, redirect_uri: @redirect_uri, code_challenge: params[:code_challenge],
        resource: OauthMetadata.resource(request.base_url), request: request)
      redirect_to callback_url(code: code), allow_other_host: true
    else
      redirect_to callback_url(error: "access_denied"), allow_other_host: true
    end
  end

  private

  def load_authorization_request
    @client = OauthClient.find_by(client_id: params[:client_id].to_s)
    @redirect_uri = params[:redirect_uri].to_s
    return render_invalid("This app isn't registered with the planner. Remove the connector and add it again.") unless @client
    return render_invalid("This app asked to return somewhere it didn't register. Remove the connector and add it again.") unless @client.accepts_redirect_uri?(@redirect_uri)
    return redirect_to(callback_url(error: "unsupported_response_type"), allow_other_host: true) unless params[:response_type] == "code"
    return redirect_to(callback_url(error: "invalid_request", error_description: "PKCE with S256 is required"), allow_other_host: true) unless params[:code_challenge].to_s.match?(/\A[A-Za-z0-9_-]{43}\z/) && params[:code_challenge_method] == "S256"

    redirect_to(callback_url(error: "invalid_target"), allow_other_host: true) unless OauthMetadata.accepts_resource?(request.base_url, params[:resource])
  end

  def render_invalid(message)
    @message = message
    render :invalid, status: :bad_request
  end

  def callback_url(**result)
    uri = URI.parse(@redirect_uri)
    extra = result.merge(state: params[:state].presence, iss: request.base_url).compact
    uri.query = URI.encode_www_form(URI.decode_www_form(uri.query.to_s) + extra.map { |key, value| [key.to_s, value] })
    uri.to_s
  end
end
