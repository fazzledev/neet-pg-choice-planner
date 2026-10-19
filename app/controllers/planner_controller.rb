class PlannerController < ApplicationController
  allow_unauthenticated_access only: :show

  def show
    resume_session
    @counselling = current_counselling
    @list = current_user&.choice_list_for(@counselling)
  end
end
