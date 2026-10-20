module Admin
  class StatsController < ApplicationController
    before_action :require_admin

    WINDOWS = { "7 days" => 7.days, "30 days" => 30.days }.freeze

    def show
      @signed_in = User.where.not(last_signed_in_at: nil)
      @with_choices = ChoiceList.where(counselling: current_counselling).joins(:picks).distinct.count(:user_id)
      @windows = WINDOWS.transform_values do |span|
        {
          joined: @signed_in.where(created_at: span.ago..).count,
          signed_in: @signed_in.where(last_signed_in_at: span.ago..).count,
          edited: ChoiceList.where(counselling: current_counselling).joins(:snapshots).where(snapshots: { created_at: span.ago.. }).distinct.count(:user_id),
          assistants: OauthGrant.where(last_used_at: span.ago..).distinct.count(:user_id)
        }
      end
      @goatcounter_url = Rails.configuration.x.goatcounter_url
    end
  end
end
