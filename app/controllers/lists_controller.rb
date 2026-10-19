class ListsController < ApplicationController
  def show
    @list = find_choice_list or return
    @counselling = @list.counselling
    render "planner/show"
  end

  def export
    @list = find_choice_list or return
    send_data ListExport.new(@list).to_csv, filename: "choices-#{@list.user.email.split("@").first}-#{Time.current.strftime("%Y%m%d-%H%M")}.csv", type: "text/csv"
  end
end
