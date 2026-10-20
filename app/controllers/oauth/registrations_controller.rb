class Oauth::RegistrationsController < ActionController::API
  rate_limit to: 30, within: 1.hour, with: -> { render json: { error: "slow_down", error_description: "Too many registrations. Try again later." }, status: :too_many_requests }

  def create
    metadata = JSON.parse(request.raw_post)
    client = OauthClient.register(metadata)
    render json: client.as_registration, status: :created
  rescue JSON::ParserError, NoMethodError, TypeError
    render json: { error: "invalid_client_metadata", error_description: "Send the client metadata as a JSON object." }, status: :bad_request
  rescue OauthClient::Invalid => error
    render json: { error: "invalid_redirect_uri", error_description: error.message }, status: :bad_request
  end
end
