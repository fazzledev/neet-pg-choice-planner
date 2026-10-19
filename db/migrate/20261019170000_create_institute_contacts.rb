class CreateInstituteContacts < ActiveRecord::Migration[8.1]
  def change
    create_table :institute_contacts do |t|
      t.string :institute_code, null: false, index: { unique: true }
      t.string :confidence
      t.date :researched_on
      t.json :details, null: false, default: {}
      t.timestamps
    end
  end
end
