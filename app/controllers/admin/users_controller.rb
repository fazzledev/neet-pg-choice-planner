module Admin
  class UsersController < ApplicationController
    before_action :require_admin

    def index
      @users = User.listed.order(:email).includes(:choice_lists)
      @user = User.new
      @counselling = current_counselling
    end

    def create
      @user = User.new(params.expect(user: %i[email name roll_number]).merge(added_by_admin: true))
      if @user.save
        SignInMailer.invite(@user).deliver_later if params[:send_invite] == "1"
        redirect_to admin_users_path, notice: "Added #{@user.email}."
      else
        @users = User.listed.order(:email).includes(:choice_lists)
        @counselling = current_counselling
        render :index, status: :unprocessable_entity
      end
    end

    def invite
      user = User.find(params[:id])
      SignInMailer.invite(user).deliver_later
      redirect_to admin_users_path, notice: "Sign-in link sent to #{user.email}."
    end
  end
end
