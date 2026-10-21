require "test_helper"

class ExtensionDownloadTest < ActionDispatch::IntegrationTest
  test "shows install steps without signing in" do
    get extension_path
    assert_response :success
    assert_match "Load unpacked", response.body
  end

  test "downloads the extension as a zip of its folder" do
    get download_extension_path
    assert_response :success
    assert_equal "application/zip", response.media_type

    names = Zip::File.open_buffer(response.body).map(&:name)
    assert_includes names, "manifest.json"
    assert_includes names, "portal.js"
    assert_includes names, "icons/icon-128.png"
  end
end
