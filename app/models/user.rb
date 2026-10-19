class User < ApplicationRecord
  SIGN_IN_LINK_TTL = 20.minutes
  INVITE_TTL = 7.days
  RESEND_COOLDOWN = 2.minutes

  has_many :sessions, dependent: :destroy
  has_many :choice_lists, dependent: :destroy

  normalizes :email, with: -> { _1.strip.downcase }
  validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }

  generates_token_for :sign_in, expires_in: SIGN_IN_LINK_TTL do
    sign_in_version
  end

  generates_token_for :invite, expires_in: INVITE_TTL do
    sign_in_version
  end

  scope :listed, -> { where(added_by_admin: true).or(where(admin: true)).or(where.not(last_signed_in_at: nil)) }

  def self.for_email(email)
    email = email.to_s.strip.downcase
    find_by(email: email) || create!(email: email)
  rescue ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid => error
    find_by(email: email) or raise error
  end

  def self.consume_sign_in_token(token)
    user = (find_by_token_for(:sign_in, token) || find_by_token_for(:invite, token)) or return
    user.increment!(:sign_in_version)
    user.update_column(:last_signed_in_at, Time.current)
    user
  end

  def claim_sign_in_link!
    with_lock do
      return false if sign_in_link_sent_at&.after?(RESEND_COOLDOWN.ago)

      update!(sign_in_link_sent_at: Time.current)
    end
    true
  end

  def display_name
    name.presence || email
  end

  def choice_list_for(counselling)
    choice_lists.create_or_find_by!(counselling: counselling)
  end
end
