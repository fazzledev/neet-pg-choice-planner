class InstituteContact < ApplicationRecord
  FIELDS = %w[hospital dnb_contact_name designation email phone other_contacts orthopaedics_notes sources confidence notes].freeze

  validates :institute_code, presence: true, uniqueness: true

  def self.import(path)
    data = JSON.parse(File.read(path))
    researched_on = data["researched_on"]
    transaction do
      data.fetch("contacts").map do |row|
        contact = find_or_initialize_by(institute_code: row.fetch("code"))
        contact.update!(confidence: row["confidence"], researched_on: researched_on, details: row.slice(*FIELDS))
        contact
      end
    end
  end

  def self.catalog_map
    all.to_h { |c| [c.institute_code, c.details.merge("researched_on" => c.researched_on&.iso8601)] }
  end
end
