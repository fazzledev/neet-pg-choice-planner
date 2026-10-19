class CreateUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :users do |t|
      t.string :email, null: false, index: { unique: true }
      t.string :name
      t.boolean :admin, null: false, default: false
      t.string :roll_number
      t.integer :sign_in_version, null: false, default: 0
      t.datetime :last_signed_in_at
      t.timestamps
    end
  end
end
