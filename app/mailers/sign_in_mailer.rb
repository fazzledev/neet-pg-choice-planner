class SignInMailer < ApplicationMailer
  def link(user)
    @user = user
    @url = sign_in_link_url(user.generate_token_for(:sign_in))
    mail to: user.email, subject: "Your NEET PG Choice Planner sign-in link"
  end

  def invite(user)
    @user = user
    @url = sign_in_link_url(user.generate_token_for(:invite))
    mail to: user.email, subject: "You're invited to NEET PG Choice Planner"
  end
end
