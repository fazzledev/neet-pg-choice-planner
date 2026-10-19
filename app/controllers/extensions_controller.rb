class ExtensionsController < ApplicationController
  allow_unauthenticated_access

  def show
    @version = ExtensionPackage.version
  end

  def download
    send_data ExtensionPackage.zip, filename: "#{ExtensionPackage::FOLDER}-#{ExtensionPackage.version}.zip", type: "application/zip"
  end
end
