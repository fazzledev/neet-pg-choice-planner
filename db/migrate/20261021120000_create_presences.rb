class CreatePresences < ActiveRecord::Migration[8.1]
  def change
    create_table :presences do |t|
      t.string :tab_id, null: false, index: { unique: true }
      t.boolean :signed_in, null: false, default: false
      t.datetime :last_seen_at, null: false, index: true
    end
  end
end
