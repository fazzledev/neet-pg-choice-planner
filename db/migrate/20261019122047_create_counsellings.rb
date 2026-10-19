class CreateCounsellings < ActiveRecord::Migration[8.1]
  def change
    create_table :counsellings do |t|
      t.string :name, null: false
      t.string :slug, null: false, index: { unique: true }
      t.boolean :active, null: false, default: false
      t.timestamps
    end
  end
end
