class CreateChoices < ActiveRecord::Migration[8.1]
  def change
    create_table :choices do |t|
      t.references :counselling, null: false, foreign_key: true
      t.references :institute, null: false, foreign_key: true
      t.references :program, null: false, foreign_key: true
      t.string :quota, null: false
      t.integer :sr
      t.timestamps
      t.index %i[institute_id program_id quota], unique: true
    end
  end
end
