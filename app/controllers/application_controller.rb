class ApplicationController < ActionController::Base
  include Authentication

  allow_browser versions: :modern

  private

  def require_admin
    head :forbidden unless current_user&.admin?
  end

  def current_counselling
    @current_counselling ||= Counselling.current or raise ActiveRecord::RecordNotFound, "no counselling imported yet"
  end

  def find_choice_list
    list = ChoiceList.find(params[:list_id] || params[:id])
    return list if list.user_id == current_user.id || current_user.admin?

    head :not_found
    nil
  end
end
