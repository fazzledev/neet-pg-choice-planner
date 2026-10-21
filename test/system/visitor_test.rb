require "application_system_test_case"

class VisitorTest < ApplicationSystemTestCase
  setup do
    import_catalog
    Rails.configuration.x.goatcounter_url = "https://stats.example.com"
    page.driver.browser.execute_cdp("Page.addScriptToEvaluateOnNewDocument", source: <<~JS)
      window.goatcounter = { allow_local: true }
      window.beacons = []
      navigator.sendBeacon = (url) => { window.beacons.push(new URL(url).searchParams.get("p")); return true }
    JS
  end

  teardown { Rails.configuration.x.goatcounter_url = nil }

  test "a new browser counts one first visit, then one returning visit per day" do
    visit root_path
    assert_beacon "visitor/first"

    visit privacy_path
    assert_page_loaded
    assert_not_includes beacons, "visitor/first"
    assert_not_includes beacons, "visitor/returning"

    page.execute_script(%(localStorage.setItem("planner:visitor", JSON.stringify({ lastCounted: "2000-01-01" }))))
    visit privacy_path
    assert_beacon "visitor/returning"
  end

  private

  def beacons
    page.evaluate_script("window.beacons")
  end

  def assert_page_loaded
    assert page.evaluate_async_script(<<~JS)
      const done = arguments[0]
      if (document.readyState === "complete") setTimeout(() => done(true), 50)
      else window.addEventListener("load", () => setTimeout(() => done(true), 50))
    JS
  end

  def assert_beacon(name)
    assert_page_loaded
    assert_includes beacons, name
  end
end
