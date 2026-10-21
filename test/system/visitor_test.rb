require "application_system_test_case"

class VisitorTest < ApplicationSystemTestCase
  setup do
    import_catalog
    Rails.configuration.x.goatcounter_url = "https://stats.example.com"
    @injected = page.driver.browser.execute_cdp("Page.addScriptToEvaluateOnNewDocument", source: <<~JS)["identifier"]
      window.goatcounter = { allow_local: true }
      window.beacons = []
      navigator.sendBeacon = (url) => { window.beacons.push(new URL(url).searchParams.get("p")); return true }
    JS
  end

  teardown do
    page.driver.browser.execute_cdp("Page.removeScriptToEvaluateOnNewDocument", identifier: @injected)
    Rails.configuration.x.goatcounter_url = nil
  end

  test "a new browser counts one first visit, then one returning visit per day" do
    visit root_path
    assert_equal ["visitor/first"], visitor_beacons

    visit privacy_path
    assert_empty visitor_beacons

    page.execute_script(%(localStorage.setItem("planner:visitor", JSON.stringify({ lastCounted: "2000-01-01" }))))
    visit privacy_path
    assert_equal ["visitor/returning"], visitor_beacons
  end

  test "a browser that opted out of GoatCounter is neither counted nor noted" do
    visit privacy_path
    page.execute_script(%(localStorage.removeItem("planner:visitor"); localStorage.setItem("skipgc", "t")))
    visit root_path
    assert_empty visitor_beacons
    assert_nil page.evaluate_script(%(localStorage.getItem("planner:visitor")))
  end

  test "a corrupt note counts as a returning visit" do
    visit privacy_path
    page.execute_script(%(localStorage.setItem("planner:visitor", "{not json")))
    visit root_path
    assert_equal ["visitor/returning"], visitor_beacons
  end

  private

  def visitor_beacons
    assert_page_loaded
    page.evaluate_script("window.beacons").grep(%r{\Avisitor/})
  end

  def assert_page_loaded
    assert page.evaluate_async_script(<<~JS)
      const done = arguments[0]
      if (document.readyState === "complete") setTimeout(() => done(true), 50)
      else window.addEventListener("load", () => setTimeout(() => done(true), 50))
    JS
  end
end
