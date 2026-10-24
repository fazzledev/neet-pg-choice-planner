module ConnectionsHelper
  ASSISTANT_ICONS = { "chatgpt" => "openai", "claude" => "claude", "other" => "sparkles" }.freeze

  EXAMPLE_QUESTIONS = [
    "Find MD Radiodiagnosis seats in government colleges in Karnataka and add them after my top five.",
    "Move every DNB choice below my MD and MS choices.",
    "Who is the DNB coordinator for the hospitals in my plan in Kerala?"
  ].freeze

  def ask_prompt(question) = "Using NEET PG Choice Planner: #{question}"

  def ask_chatgpt_url(question) = "https://chatgpt.com/?q=#{ERB::Util.url_encode(ask_prompt(question))}"

  def ask_claude_url(question) = "https://claude.ai/new?q=#{ERB::Util.url_encode(ask_prompt(question))}"

  def assistant_brand(grant)
    names = [grant.oauth_client.client_name, grant.oauth_client.redirect_label(grant.redirect_uri)]
    if names.any? { _1.match?(/chatgpt|openai/i) } then "chatgpt"
    elsif names.any? { _1.match?(/claude|anthropic/i) } then "claude"
    else "other"
    end
  end
end
