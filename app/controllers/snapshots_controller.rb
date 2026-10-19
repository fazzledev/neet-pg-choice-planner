class SnapshotsController < ApplicationController
  def index
    list = find_choice_list or return
    render json: list.snapshots.order(id: :desc).map { { id: _1.id, created_at: _1.created_at.iso8601, label: _1.label, count: _1.picks.size } }
  end

  def restore
    list = find_choice_list or return
    render json: list.restore!(list.snapshots.find(params[:id]))
  end
end
