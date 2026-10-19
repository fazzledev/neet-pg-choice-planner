class CreateChoiceLists < ActiveRecord::Migration[8.1]
  def change
    create_table :choice_lists do |t|
      t.references :user, null: false, foreign_key: true
      t.references :counselling, null: false, foreign_key: true
      t.integer :revision, null: false, default: 0
      t.timestamps
      t.index %i[user_id counselling_id], unique: true
    end
  end
end
