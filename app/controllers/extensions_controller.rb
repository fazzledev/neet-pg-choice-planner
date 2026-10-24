class ExtensionsController < ApplicationController
  allow_unauthenticated_access

  def show
    @version = ExtensionPackage.version
    @browser = browser_family(request.user_agent.to_s)
    @firefox_badge = @browser == :firefox && ExtensionPackage.firefox_listed
    response.headers["Vary"] = "User-Agent"
  end

  def browser_family(user_agent)
    if user_agent.include?("Firefox/") then :firefox
    elsif user_agent.match?(%r{Chrome/|Chromium/|Edg/}) then :chromium
    else :other
    end
  end
  private :browser_family

  def download
    send_data ExtensionPackage.zip, filename: "#{ExtensionPackage::FOLDER}-#{ExtensionPackage.version}.zip", type: "application/zip"
  end
end
