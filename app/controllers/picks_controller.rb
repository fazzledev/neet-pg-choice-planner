class PicksController < ApplicationController
  rescue_from ChoiceList::Conflict, with: -> { render json: { error: _1.message }, status: :conflict }
  rescue_from ChoiceList::Invalid, with: -> { render json: { error: _1.message }, status: :unprocessable_entity }

  def show
    list = find_choice_list or return
    render json: list.as_payload
  end

  def update
    list = find_choice_list or return
    base = Integer(params[:base], exception: false) or raise ChoiceList::Conflict, "missing base revision"
    render json: list.replace_picks!(params.to_unsafe_h["picks"], base: base, label: params[:label].presence&.to_s&.first(40), session_id: Current.session.id)
  end
end
