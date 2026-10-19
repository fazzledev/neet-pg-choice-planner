class AddSessionToSnapshotsAndSignInTracking < ActiveRecord::Migration[8.1]
  def change
    add_column :snapshots, :session_id, :integer
    add_column :users, :sign_in_link_sent_at, :datetime
    add_column :users, :added_by_admin, :boolean, null: false, default: false
  end
end
