class ChoiceList < ApplicationRecord
  SNAPSHOT_LIMIT = 300
  COALESCE_WINDOW = 5.minutes
  NOTE_LIMIT = 500

  class Conflict < StandardError; end
  class Invalid < StandardError; end

  belongs_to :user
  belongs_to :counselling
  has_many :picks, -> { order(:position) }, dependent: :delete_all
  has_many :snapshots, dependent: :delete_all

  def as_payload
    { revision: revision, picks: picks.map { { choice_id: _1.choice_id, note: _1.note.to_s } } }
  end

  def replace_picks!(items, base: nil, label: nil, session_id: nil)
    rows = normalize(items)
    transaction do
      lock!
      raise Conflict, "changed elsewhere" if base && Integer(base, exception: false) != revision

      picks.delete_all
      now = Time.current
      Pick.insert_all(rows.each_with_index.map { |(id, note), i| { choice_list_id: self.id, choice_id: id, position: i + 1, note: note, created_at: now, updated_at: now } }) if rows.any?
      increment!(:revision)
      record_snapshot(label, session_id)
    end
    picks.reset
    Turbo::StreamsChannel.broadcast_action_to self, action: :plan_changed, target: "planner", attributes: { revision: revision }
    as_payload
  end

  def restore!(snapshot)
    items = snapshot.picks.map { { "choice_id" => _1["choice_id"], "note" => _1["note"] } }
    replace_picks!(items, label: "Restored from ##{snapshot.id}")
  end

  private

  def normalize(items)
    raise Invalid, "picks must be a list of objects" unless items.is_a?(Array) && items.all? { _1.respond_to?(:to_h) && !_1.is_a?(Array) }

    rows = items.map do |item|
      item = item.to_h.stringify_keys
      id = Integer(item["choice_id"], exception: false) or raise Invalid, "bad choice_id"
      [id, item["note"].to_s.strip[0, NOTE_LIMIT]]
    end
    ids = rows.map(&:first)
    raise Invalid, "duplicate choices" unless ids.uniq.size == ids.size
    raise Invalid, "unknown choices" unless counselling.choices.where(id: ids).count == ids.size

    rows
  end

  def record_snapshot(label, session_id)
    data = picks.reload.map { { "choice_id" => _1.choice_id, "note" => _1.note.to_s } }
    latest = snapshots.order(:id).last
    if label.nil? && session_id && latest && latest.label.nil? && latest.session_id == session_id && latest.created_at > COALESCE_WINDOW.ago
      latest.update_columns(picks: data, updated_at: Time.current)
    else
      snapshots.create!(label: label, picks: data, session_id: session_id)
    end
    stale = snapshots.where(label: nil).order(id: :desc).offset(SNAPSHOT_LIMIT).pluck(:id)
    snapshots.where(id: stale).delete_all if stale.any?
  end
end
