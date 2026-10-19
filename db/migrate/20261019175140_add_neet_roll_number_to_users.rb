class AddNeetRollNumberToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :neet_roll_number, :string
  end
end
