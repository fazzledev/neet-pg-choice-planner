module ConnectionsHelper
  ASSISTANT_ICONS = { "chatgpt" => "openai", "claude" => "claude", "other" => "sparkles" }.freeze

  def assistant_brand(grant)
    names = [grant.oauth_client.client_name, grant.oauth_client.redirect_label(grant.redirect_uri)]
    if names.any? { _1.match?(/chatgpt|openai/i) } then "chatgpt"
    elsif names.any? { _1.match?(/claude|anthropic/i) } then "claude"
    else "other"
    end
  end
end
