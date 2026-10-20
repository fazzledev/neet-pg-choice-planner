class Session < ApplicationRecord
  belongs_to :user
  has_one :oauth_grant, dependent: :delete
end
