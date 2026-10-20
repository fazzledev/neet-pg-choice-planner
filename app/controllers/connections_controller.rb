class ConnectionsController < ApplicationController
  allow_unauthenticated_access only: :index

  def index
    resume_session
    @server_url = OauthMetadata.resource(request.base_url)
    @grants = current_user ? current_user.oauth_grants.active.includes(:oauth_client).order(created_at: :desc) : []
  end

  def destroy
    current_user.oauth_grants.find(params[:id]).disconnect!
    redirect_to connect_path, notice: "Disconnected."
  end
end
