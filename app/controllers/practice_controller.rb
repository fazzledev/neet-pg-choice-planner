class PracticeController < ApplicationController
  allow_unauthenticated_access

  def show
    @counselling = current_counselling
  end
end
