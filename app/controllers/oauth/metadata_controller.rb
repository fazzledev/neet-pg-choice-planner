class Oauth::MetadataController < ActionController::API
  def protected_resource
    render json: OauthMetadata.protected_resource(request.base_url)
  end

  def authorization_server
    render json: OauthMetadata.authorization_server(request.base_url)
  end
end
