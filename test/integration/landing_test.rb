require "test_helper"

class LandingTest < ActionDispatch::IntegrationTest
  test "shows the landing page at the root and links to the planner" do
    get root_path
    assert_response :success
    assert_select "a[href='#{planner_path}']", minimum: 2
    assert_match "not affiliated with the Medical Counselling Committee", response.body
  end

  test "shows the planner demo without downloading it up front" do
    get root_path
    assert_select ".lp-hero video.lp-demo-video[muted][playsinline][controls][preload=none][poster][aria-label]" do |video|
      assert_match %r{/assets/planner-demo-\h+\.mp4}, video.first["src"]
    end
    assert_select "script[src*=landing][defer]"
    assert_select "link[rel=modulepreload]", count: 0
  end

  test "compares the portal with the planner and shows the planner without scripts" do
    get root_path
    assert_select ".lp-compare[data-view=planner]" do
      assert_select "h2", text: /choices\. None of the pain\./
      assert_select "button[data-show=planner][aria-pressed=true]"
      assert_select "button[data-show=portal][aria-pressed=false]"
      assert_select ".lp-flip", count: PagesHelper::PORTAL_VS_PLANNER.size do |cards|
        cards.each do |card|
          assert_select card, ".lp-face.portal", count: 1
          assert_select card, ".lp-face.planner", count: 1
        end
      end
    end
  end

  test "offers a share button that shares the site" do
    get root_path
    assert_select ".lp-cta details.share-menu[data-share-url='#{root_url}']" do
      assert_select "summary[data-goatcounter-click='landing/share-open']", text: "Share with a friend"
      assert_select "button.share-copy", text: "Copy"
      assert_select "a[href='https://wa.me/?text=#{ERB::Util.url_encode("#{ShareHelper::SHARE_TEXT} #{root_url}")}']"
    end
    assert_select "script[src*=share][defer]"
    assert_select "script[src*=menus][defer]"
  end

  test "every landing link is counted as its own click event" do
    get root_path
    links = css_select("a")
    assert links.any?
    names = links.map { _1["data-goatcounter-click"] }
    assert_equal links.size, names.compact.size, "untagged: #{links.reject { _1["data-goatcounter-click"] }.map(&:text).map(&:strip)}"
    assert_equal names.uniq, names
    assert names.all? { _1.start_with?("landing/") }, "not landing/: #{names.reject { _1.start_with?("landing/") }}"
  end

  test "lets visitors call, WhatsApp or email from the footer" do
    [root_path, privacy_path].each do |path|
      get path
      assert_select "footer a[href='tel:+919940689619']"
      assert_select "footer a[href='https://wa.me/919940689619']"
      assert_select "footer a[href='mailto:hey@fazzle.dev']"
    end
  end

  test "every privacy page link is counted as its own click event" do
    get privacy_path
    links = css_select("a")
    assert links.any?
    names = links.map { _1["data-goatcounter-click"] }
    assert_equal links.size, names.compact.size, "untagged: #{links.reject { _1["data-goatcounter-click"] }.map(&:text).map(&:strip)}"
    assert_equal names.uniq, names
    assert names.all? { _1.start_with?("privacy/") }, "not privacy/: #{names.reject { _1.start_with?("privacy/") }}"
  end

  test "shows the privacy page and links it from the landing page" do
    get privacy_path
    assert_response :success
    assert_match "hey@fazzle.dev", response.body
    get root_path
    assert_select "a[href='#{privacy_path}']"
  end

  test "redirects the old domain to the new one, keeping the path" do
    host! "mcc.fazzle.dev"
    get "/plan?view=institute"
    assert_redirected_to "https://neet-pg-choice-planner.fazzle.dev/plan?view=institute"

    host! "neet-pg-choices.fazzle.dev"
    get "/"
    assert_redirected_to "https://neet-pg-choice-planner.fazzle.dev/"
  end
end
