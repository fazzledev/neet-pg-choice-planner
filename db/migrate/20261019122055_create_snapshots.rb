class CreateSnapshots < ActiveRecord::Migration[8.1]
  def change
    create_table :snapshots do |t|
      t.references :choice_list, null: false, foreign_key: true
      t.string :label
      t.json :picks, null: false, default: []
      t.timestamps
    end
  end
end
