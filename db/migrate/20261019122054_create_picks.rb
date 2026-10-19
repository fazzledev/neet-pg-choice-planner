class CreatePicks < ActiveRecord::Migration[8.1]
  def change
    create_table :picks do |t|
      t.references :choice_list, null: false, foreign_key: true
      t.references :choice, null: false, foreign_key: true
      t.integer :position, null: false
      t.text :note
      t.timestamps
      t.index %i[choice_list_id position], unique: true
      t.index %i[choice_list_id choice_id], unique: true
    end
  end
end
