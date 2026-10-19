class AddNeetPasswordDigestToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :neet_password_digest, :string
  end
end
