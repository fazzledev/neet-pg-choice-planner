class Presence < ApplicationRecord
  ACTIVE_WINDOW = 2.minutes
  KEPT_FOR = 1.day
  TAB_ID = /\A[0-9a-f-]{36}\z/

  scope :active, -> { where(last_seen_at: ACTIVE_WINDOW.ago..) }
  scope :expired, -> { where(last_seen_at: ...KEPT_FOR.ago) }

  def self.seen!(tab_id, signed_in:)
    upsert({ tab_id: tab_id, signed_in: signed_in, last_seen_at: Time.current }, unique_by: :tab_id)
  end
end
