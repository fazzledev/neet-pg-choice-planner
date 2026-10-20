class OauthGrant < ApplicationRecord
  SCOPE = "plan".freeze
  CODE_TTL = 5.minutes
  ACCESS_TTL = 1.hour
  REFRESH_TTL = 90.days

  belongs_to :oauth_client
  belongs_to :user
  belongs_to :session

  scope :active, -> { where(refresh_expires_at: Time.current..) }
  scope :stale, -> { where(refresh_expires_at: ...Time.current).or(where(access_token_digest: nil, code_expires_at: ...1.day.ago)) }

  def self.digest(token)
    Digest::SHA256.hexdigest(token.to_s)
  end

  def self.start(client:, user:, redirect_uri:, code_challenge:, resource:, request:)
    code = SecureRandom.urlsafe_base64(32)
    transaction do
      session = user.sessions.create!(user_agent: "#{client.client_name} (connector)", ip_address: request.remote_ip)
      create!(oauth_client: client, user: user, session: session, redirect_uri: redirect_uri, scope: SCOPE, resource: resource,
        code_digest: digest(code), code_challenge: code_challenge, code_expires_at: CODE_TTL.from_now)
    end
    code
  end

  def self.redeem_code(code, client:, redirect_uri:, code_verifier:)
    grant = find_by(code_digest: digest(code), oauth_client: client) or return
    grant.with_lock do
      if grant.code_used_at
        grant.session.destroy
        return
      end
      return unless grant.code_expires_at.future? && (redirect_uri.nil? || grant.redirect_uri == redirect_uri) && grant.verifies?(code_verifier)

      grant.update!(code_used_at: Time.current)
      grant.issue_tokens!
    end
  end

  def self.refresh(token, client:)
    grant = active.find_by(refresh_token_digest: digest(token), oauth_client: client) or return
    grant.with_lock { grant.refresh_token_digest == digest(token) ? grant.issue_tokens! : nil }
  end

  def self.authenticate(token)
    return if token.blank?

    grant = find_by(access_token_digest: digest(token)) or return
    return unless grant.access_expires_at&.future?

    grant.touch(:last_used_at) if grant.last_used_at.nil? || grant.last_used_at.before?(5.minutes.ago)
    grant
  end

  def verifies?(code_verifier)
    return false unless code_verifier.is_a?(String) && code_verifier.match?(/\A[A-Za-z0-9\-._~]{43,128}\z/)

    expected = Base64.urlsafe_encode64(Digest::SHA256.digest(code_verifier), padding: false)
    ActiveSupport::SecurityUtils.secure_compare(expected, code_challenge)
  end

  def issue_tokens!
    access = SecureRandom.urlsafe_base64(32)
    refresh = SecureRandom.urlsafe_base64(32)
    update!(access_token_digest: self.class.digest(access), access_expires_at: ACCESS_TTL.from_now,
      refresh_token_digest: self.class.digest(refresh), refresh_expires_at: REFRESH_TTL.from_now)
    { access_token: access, token_type: "Bearer", expires_in: ACCESS_TTL.to_i, refresh_token: refresh, scope: scope }
  end

  def disconnect!
    session.destroy
  end
end
