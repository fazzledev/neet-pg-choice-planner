require "application_system_test_case"

class ExtensionPageTest < ApplicationSystemTestCase
  test "a computer gets the Chrome Web Store link, with the zip as a fallback" do
    visit extension_path
    assert_link "Add to Chrome", href: ExtensionPackage::CHROME_WEB_STORE_URL
    assert_no_link "Download the zip"
    find(".manual-install summary").click
    assert_link "Download the zip", href: download_extension_path
    assert_no_text "Needs Chrome on a laptop or desktop"
    assert_no_text "Then, on your computer:"
  end

  test "a phone is told to open the page on a computer instead" do
    emulate_phone do
      visit extension_path
      assert_text "Needs Chrome on a laptop or desktop"
      assert_equal extension_url, find("input[aria-label='Link to this page']").value
      assert_link "WhatsApp", href: %r{\Ahttps://wa.me/}
      assert_link "Email", href: /\Amailto:/
      assert_no_link "Download", exact: true
      assert_text "Then, on your computer:"

      page.driver.browser.execute_cdp("Browser.grantPermissions", permissions: ["clipboardReadWrite", "clipboardSanitizedWrite"])
      find(".link-copy button").click
      assert_button "Copied"
      assert_text "Link copied. Paste it into a chat or email to yourself"
    end
  end

  private

  def emulate_phone
    browser = page.driver.browser
    browser.execute_cdp("Emulation.setDeviceMetricsOverride", width: 390, height: 844, deviceScaleFactor: 2, mobile: true)
    browser.execute_cdp("Emulation.setTouchEmulationEnabled", enabled: true, maxTouchPoints: 5)
    yield
  ensure
    browser.execute_cdp("Emulation.setTouchEmulationEnabled", enabled: false)
    browser.execute_cdp("Emulation.clearDeviceMetricsOverride")
  end
end
