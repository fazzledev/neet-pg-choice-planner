class PagesController < ApplicationController
  allow_unauthenticated_access

  def privacy
  end

  def home
    @counselling = Counselling.current
    @choice_count = @counselling&.choices&.count.to_i
    @institute_count = @counselling&.institutes&.count.to_i
  end
end
