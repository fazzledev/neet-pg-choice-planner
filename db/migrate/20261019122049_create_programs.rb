class CreatePrograms < ActiveRecord::Migration[8.1]
  def change
    create_table :programs do |t|
      t.references :counselling, null: false, foreign_key: true
      t.string :code, null: false
      t.string :name, null: false
      t.string :course, null: false
      t.string :speciality, null: false
      t.timestamps
      t.index %i[counselling_id code], unique: true
    end
  end
end
