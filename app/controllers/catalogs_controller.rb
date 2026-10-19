class CatalogsController < ApplicationController
  allow_unauthenticated_access

  def show
    counselling = Counselling.find(params[:id])
    json = counselling.catalog_json
    render json: json if stale?(etag: Digest::SHA256.hexdigest(json), public: true)
  end
end
