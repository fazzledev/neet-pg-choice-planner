class SessionsController < ApplicationController
  allow_unauthenticated_access only: %i[new create show consume]
  rate_limit to: 5, within: 10.minutes, only: :create, with: -> { redirect_to new_session_path, alert: "Too many requests. Try again in a few minutes." }

  def new
    redirect_to root_path if authenticated?
  end

  def create
    user = User.for_email(params[:email]) rescue nil
    SignInMailer.link(user).deliver_later if user&.claim_sign_in_link!
    redirect_to new_session_path(sent: 1)
  end

  def show
    @token = params[:token]
  end

  def consume
    if (user = User.consume_sign_in_token(params[:token]))
      start_new_session_for(user)
      redirect_to after_authentication_url
    else
      redirect_to new_session_path, alert: "That sign-in link has expired or was already used. Request a new one."
    end
  end

  def destroy
    terminate_session
    redirect_to new_session_path
  end
end
