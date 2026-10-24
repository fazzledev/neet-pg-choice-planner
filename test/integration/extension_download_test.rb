require "test_helper"

class ExtensionDownloadTest < ActionDispatch::IntegrationTest
  test "shows install steps without signing in" do
    get extension_path
    assert_response :success
    assert_match "Load unpacked", response.body
  end

  test "counts every way off the extension page" do
    get extension_path
    assert_select "a[href='#{download_extension_path}'][data-goatcounter-click='extension-page/download']"
    assert_select ".link-copy input[value='#{extension_url}']"
    assert_select ".link-copy button[data-goatcounter-click='extension-page/copy-link']"
    assert_select "a[data-goatcounter-click='extension-page/source']"
    assert_select "a[data-goatcounter-click='extension-page/add-to-chrome'][href='#{ExtensionPackage::CHROME_WEB_STORE_URL}']"
    assert_select "a[data-goatcounter-click='extension-page/store-anyway'][href='#{ExtensionPackage::CHROME_WEB_STORE_URL}']"
    assert_select "a[data-goatcounter-click='extension-page/whatsapp-link'][href='https://wa.me/?text=#{ERB::Util.url_encode("Install the MCC filler on my computer: #{extension_url}")}']"
    assert_select "a[data-goatcounter-click='extension-page/email-link'][href^='mailto:?subject=']"
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
