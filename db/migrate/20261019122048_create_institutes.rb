class CreateInstitutes < ActiveRecord::Migration[8.1]
  def change
    create_table :institutes do |t|
      t.references :counselling, null: false, foreign_key: true
      t.string :code, null: false
      t.string :name, null: false
      t.text :address
      t.string :type_code
      t.string :type_name
      t.string :state
      t.boolean :state_doubtful, null: false, default: false
      t.timestamps
      t.index %i[counselling_id code], unique: true
    end
  end
end
