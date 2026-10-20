module AnalyticsHelper
  def goatcounter_tag
    return unless (url = Rails.configuration.x.goatcounter_url)
    return if controller_path.start_with?("admin/")

    path = content_for(:analytics_path) || request.path
    javascript_include_tag "goatcounter", async: true, data: { goatcounter: "#{url}/count", goatcounter_settings: { path: path }.to_json }
  end
end
