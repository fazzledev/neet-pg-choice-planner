require "application_system_test_case"

class ExtensionPageTest < ApplicationSystemTestCase
  test "a computer gets the store badge first, then Download and Source to install by hand" do
    visit extension_path
    assert_selector ".ext-install a[href='#{ExtensionPackage::CHROME_WEB_STORE_URL}'] img[alt='Available in the Chrome Web Store']"
    assert_text "Which browsers it works in"
    within ".manual-install" do
      assert_text "Install by hand"
      assert_link "Download zip", href: download_extension_path
      assert_link "Source on GitHub"
      assert_no_text "Load unpacked"
      find("summary").click
      assert_text "Load unpacked"
    end
    assert_no_text "Send this page to your computer"
    assert_no_text "On your computer:"
  end

  test "a phone is told to open the page on a computer instead" do
    emulate_phone do
      visit extension_path
      assert_text "Send this page to your computer"
      assert_equal extension_url, find("input[aria-label='Link to this page']").value
      assert_link "WhatsApp", href: %r{\Ahttps://wa.me/}
      assert_link "Email", href: /\Amailto:/
      assert_no_link "Download", exact: true
      assert_text "On your computer:"

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
