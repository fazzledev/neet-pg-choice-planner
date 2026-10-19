class RemoveMccPortalDetailsFromUsers < ActiveRecord::Migration[8.1]
  def change
    remove_column :users, :neet_roll_number, :string
    remove_column :users, :neet_password_digest, :string
  end
end
