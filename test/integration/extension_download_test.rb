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
    assert_select "a[data-goatcounter-click='extension-page/chrome-web-store'][href='#{ExtensionPackage::CHROME_WEB_STORE_URL}']", text: "Add to Chrome"
    assert_select "a[data-goatcounter-click='extension-page/store-anyway'][href='#{ExtensionPackage::CHROME_WEB_STORE_URL}']"
    assert_select "a[data-goatcounter-click='extension-page/whatsapp-link'][href='https://wa.me/?text=#{ERB::Util.url_encode("Install the MCC filler on my computer: #{extension_url}")}']"
    assert_select "a[data-goatcounter-click='extension-page/email-link'][href^='mailto:?subject=']"
  end

  test "Chrome gets an Add to Chrome button and no Firefox note" do
    get extension_path, headers: { "User-Agent" => "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/141.0.0.0 Safari/537.36" }
    assert_select ".ext-install a.button.primary[href='#{ExtensionPackage::CHROME_WEB_STORE_URL}']", text: "Add to Chrome"
    assert_select ".ext-install img", count: 0
    assert_select ".store-note", count: 0
  end

  test "Firefox gets an Add to Firefox button" do
    get extension_path, headers: { "User-Agent" => "Mozilla/5.0 (X11; Linux x86_64; rv:144.0) Gecko/20100101 Firefox/144.0" }
    assert_select ".ext-install a[href='#{ExtensionPackage::FIREFOX_ADD_ONS_URL}'].button.primary[data-goatcounter-click='extension-page/firefox-add-ons']", text: "Add to Firefox"
    assert_select ".ext-install a[href='#{ExtensionPackage::CHROME_WEB_STORE_URL}']", count: 0
    assert_select ".store-note", count: 0
    assert_select ".ext-group-now li strong", text: "Firefox"
    assert_select ".store-anyway a[href='#{ExtensionPackage::FIREFOX_ADD_ONS_URL}']", text: "Open it in Firefox Add-ons"
  end

  test "Safari is told it needs another browser and gets a plain Add to Chrome button" do
    get extension_path, headers: { "User-Agent" => "Mozilla/5.0 (Macintosh; Intel Mac OS X 14_6) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Safari/605.1.15" }
    assert_select ".store-note strong", text: "Needs Chrome, Edge, Brave, Opera or Firefox"
    assert_select ".ext-alt a.button:not(.primary)[href='#{ExtensionPackage::CHROME_WEB_STORE_URL}']", text: "Add to Chrome"
  end

  test "browsers are grouped as available now and not supported" do
    get extension_path, headers: { "User-Agent" => "Mozilla/5.0 (Macintosh; Intel Mac OS X 14_6) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Safari/605.1.15" }
    assert_equal %w[Chrome Edge Brave Opera Firefox], css_select(".ext-group-now li strong").map(&:text)
    assert_equal ["Safari", "Chrome on phones"], css_select(".ext-group-no li strong").map(&:text)
    assert_select ".ext-group img[src*='browsers/']", count: 7
    assert_equal "User-Agent", response.headers["Vary"]
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
