class CutoffsController < ApplicationController
  allow_unauthenticated_access

  PATH = Rails.root.join("data/cutoffs/closing_ranks.json")

  def self.payload
    stamp = PATH.mtime
    @payload = nil unless @payload&.first == stamp
    @payload ||= [stamp, PATH.read].then { |time, body| [time, body, Digest::SHA256.hexdigest(body)] }
  end

  def show
    _, body, digest = self.class.payload
    expires_in 1.day, public: true
    render json: body if stale?(etag: digest, public: true)
  end
end
