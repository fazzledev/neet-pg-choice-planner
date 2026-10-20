class CutoffsController < ApplicationController
  allow_unauthenticated_access

  PATH = Rails.root.join("data/cutoffs/closing_ranks.json")

  def show
    body = PATH.read
    expires_in 1.day, public: true
    render json: body if stale?(etag: Digest::SHA256.hexdigest(body), public: true)
  end
end
