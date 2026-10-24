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
    assert_select "a[data-goatcounter-click='extension-page/chrome-web-store'][href='#{ExtensionPackage::CHROME_WEB_STORE_URL}'] img[alt='Available in the Chrome Web Store']"
    assert_select "a[data-goatcounter-click='extension-page/store-anyway'][href='#{ExtensionPackage::CHROME_WEB_STORE_URL}']"
    assert_select "a[data-goatcounter-click='extension-page/whatsapp-link'][href='https://wa.me/?text=#{ERB::Util.url_encode("Install the MCC filler on my computer: #{extension_url}")}']"
    assert_select "a[data-goatcounter-click='extension-page/email-link'][href^='mailto:?subject=']"
  end

  test "Chrome gets the Chrome Web Store badge and no Firefox note" do
    get extension_path, headers: { "User-Agent" => "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/141.0.0.0 Safari/537.36" }
    assert_select ".store-badges a[href='#{ExtensionPackage::CHROME_WEB_STORE_URL}']"
    assert_select ".store-note", count: 0
  end

  test "Firefox is told its version is in review and still gets the Chrome badge" do
    get extension_path, headers: { "User-Agent" => "Mozilla/5.0 (X11; Linux x86_64; rv:144.0) Gecko/20100101 Firefox/144.0" }
    assert_select ".store-note", text: /in Mozilla's review/
    assert_select ".store-badges a[href='#{ExtensionPackage::CHROME_WEB_STORE_URL}']"
    assert_select ".store-badges a[href='#{ExtensionPackage::FIREFOX_ADD_ONS_URL}']", count: 0
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
