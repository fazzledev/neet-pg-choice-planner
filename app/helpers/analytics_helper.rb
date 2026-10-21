module AnalyticsHelper
  def goatcounter_tag
    return unless (url = Rails.configuration.x.goatcounter_url)
    return unless counted_page?

    path = content_for(:analytics_path) || request.path
    safe_join([
      javascript_include_tag("goatcounter", async: true, data: { goatcounter: "#{url}/count", goatcounter_settings: { path: path }.to_json }),
      javascript_include_tag("visitor", defer: true)
    ])
  end

  def presence_tag
    javascript_include_tag "presence", defer: true if counted_page?
  end

  def click_event(name)
    { goatcounter_click: name, goatcounter_title: name }
  end

  private

  def counted_page?
    !controller_path.start_with?("admin/", "oauth/")
  end
end
