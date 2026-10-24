class ExtensionsController < ApplicationController
  allow_unauthenticated_access

  def show
    @version = ExtensionPackage.version
    @firefox = request.user_agent.to_s.include?("Firefox/")
  end

  def download
    send_data ExtensionPackage.zip, filename: "#{ExtensionPackage::FOLDER}-#{ExtensionPackage.version}.zip", type: "application/zip"
  end
end
