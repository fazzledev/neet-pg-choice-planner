require "application_system_test_case"

class ConnectPageTest < ApplicationSystemTestCase
  test "copying the connector link says it was copied" do
    visit connect_path
    assert_text "Plan with your AI assistant."
    assert_match %r{/mcp\z}, find("input[aria-label='Connector link']").value

    page.driver.browser.execute_cdp("Browser.grantPermissions", permissions: ["clipboardReadWrite", "clipboardSanitizedWrite"])
    within(".conn-link") { click_on "Copy" }
    assert_selector ".conn-copy[data-copied]", text: "Copied"
    assert_selector "[role=status]", text: "Copied. Paste it into your assistant."
  end

  test "lists the assistants and the other-app steps without developer tools" do
    visit connect_path
    within ".conn-setup" do
      assert_text "ChatGPT"
      assert_text "Claude"
      assert_text "Other assistant apps"
    end
    assert_no_text "Claude Code"
    assert_text "Sign in to see which assistants can reach your plan."
  end

  test "each example opens ChatGPT or Claude with the question filled in, or copies it" do
    visit connect_path
    question = ConnectionsHelper::EXAMPLE_QUESTIONS.first
    prompt = ERB::Util.url_encode("Using NEET PG Choice Planner: #{question}")
    within(first(".conn-asks li")) do
      assert_text question
      assert_link "Ask ChatGPT", href: "https://chatgpt.com/?q=#{prompt}"
      assert_link "Ask Claude", href: "https://claude.ai/new?q=#{prompt}"
      page.driver.browser.execute_cdp("Browser.grantPermissions", permissions: ["clipboardReadWrite", "clipboardSanitizedWrite"])
      click_on "Copy"
      assert_selector "[role=status]", text: "Copied. Paste it into your assistant."
    end
  end
end
