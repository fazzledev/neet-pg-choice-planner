class PresencesController < ApplicationController
  allow_unauthenticated_access
  skip_forgery_protection

  def create
    tab_id = params[:tab_id].to_s
    return head :unprocessable_content unless tab_id.match?(Presence::TAB_ID)

    Presence.seen!(tab_id, signed_in: authenticated?)
    head :no_content
  end
end
