class OauthClient < ApplicationRecord
  MAX_REDIRECT_URIS = 10
  MAX_URI_LENGTH = 2000
  NAME_LIMIT = 100
  LOOPBACK_HOSTS = %w[localhost 127.0.0.1 [::1] ::1].freeze
  FORBIDDEN_SCHEMES = %w[javascript data file vbscript blob about].freeze
  UNCLAIMED_TTL = 1.day

  class Invalid < StandardError; end

  has_many :oauth_grants, dependent: :destroy

  scope :unclaimed, -> { where.missing(:oauth_grants).where(created_at: ...UNCLAIMED_TTL.ago) }

  def self.register(metadata)
    metadata = metadata.to_h.stringify_keys
    uris = metadata["redirect_uris"]
    raise Invalid, "redirect_uris must list at least one URI" unless uris.is_a?(Array) && uris.any? && uris.size <= MAX_REDIRECT_URIS
    raise Invalid, "a redirect URI is not allowed" unless uris.all? { allowed_redirect_uri?(_1) }

    name = metadata["client_name"].to_s.squish[0, NAME_LIMIT].presence || "MCP client"
    create!(client_id: SecureRandom.uuid, client_name: name, redirect_uris: uris)
  end

  def self.allowed_redirect_uri?(value)
    return false unless value.is_a?(String) && value.length <= MAX_URI_LENGTH

    uri = URI.parse(value)
    return false if uri.fragment || uri.scheme.nil? || FORBIDDEN_SCHEMES.include?(uri.scheme.downcase)

    case uri.scheme.downcase
    when "https" then uri.host.present?
    when "http" then LOOPBACK_HOSTS.include?(uri.host)
    else true
    end
  rescue URI::InvalidURIError
    false
  end

  def accepts_redirect_uri?(value)
    redirect_uris.include?(value) || redirect_uris.any? { same_loopback_target?(_1, value) }
  end

  def redirect_label(uri)
    parsed = URI.parse(uri)
    parsed.host.presence || "#{parsed.scheme}://"
  end

  def as_registration
    {
      client_id: client_id,
      client_id_issued_at: created_at.to_i,
      client_name: client_name,
      redirect_uris: redirect_uris,
      grant_types: %w[authorization_code refresh_token],
      response_types: %w[code],
      token_endpoint_auth_method: "none"
    }
  end

  private

  def same_loopback_target?(registered, requested)
    a = URI.parse(registered)
    b = URI.parse(requested)
    a.scheme == "http" && b.scheme == "http" && LOOPBACK_HOSTS.include?(a.host) && a.host == b.host && a.path == b.path && a.query == b.query
  rescue URI::InvalidURIError
    false
  end
end
