require "application_system_test_case"

class ConnectPageTest < ApplicationSystemTestCase
  test "copying the connector link says it was copied" do
    visit connect_path
    assert_text "Plan with your AI assistant."
    assert_match %r{/mcp\z}, find("input[aria-label='Connector link']").value

    page.driver.browser.execute_cdp("Browser.grantPermissions", permissions: ["clipboardReadWrite", "clipboardSanitizedWrite"])
    click_on "Copy"
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
end
