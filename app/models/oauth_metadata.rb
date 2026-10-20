module OauthMetadata
  def self.resource(base_url)
    "#{base_url}/mcp"
  end

  def self.resource_metadata_url(base_url)
    "#{base_url}/.well-known/oauth-protected-resource/mcp"
  end

  def self.accepts_resource?(base_url, value)
    value.blank? || [resource(base_url), base_url, "#{base_url}/"].include?(value)
  end

  def self.protected_resource(base_url)
    {
      resource: resource(base_url),
      authorization_servers: [base_url],
      scopes_supported: [OauthGrant::SCOPE],
      bearer_methods_supported: ["header"],
      resource_name: "NEET PG Choice Planner",
      resource_documentation: "#{base_url}/connect"
    }
  end

  def self.authorization_server(base_url)
    {
      issuer: base_url,
      authorization_endpoint: "#{base_url}/oauth/authorize",
      token_endpoint: "#{base_url}/oauth/token",
      registration_endpoint: "#{base_url}/oauth/register",
      scopes_supported: [OauthGrant::SCOPE],
      response_types_supported: ["code"],
      response_modes_supported: ["query"],
      grant_types_supported: %w[authorization_code refresh_token],
      token_endpoint_auth_methods_supported: ["none"],
      code_challenge_methods_supported: ["S256"],
      authorization_response_iss_parameter_supported: true,
      service_documentation: "#{base_url}/connect"
    }
  end
end
