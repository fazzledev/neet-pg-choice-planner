class Counselling < ApplicationRecord
  has_many :institutes, dependent: :destroy
  has_many :programs, dependent: :destroy
  has_many :choices, dependent: :destroy
  has_many :choice_lists, dependent: :destroy

  validates :name, :slug, presence: true
  validates :slug, uniqueness: true

  def self.current
    find_by(active: true) || order(:created_at).last
  end

  def locations_json(places = InstituteLocation.all)
    places.slice(*institutes.pluck(:code)).to_json
  end

  def catalog_json
    {
      institute_types: institutes.distinct.pluck(:type_code, :type_name).to_h,
      programs: programs.order(:speciality, :course).to_h { [_1.code, [_1.name, _1.course, _1.speciality, ProgramName.icon_for(_1.speciality)]] },
      institutes: institutes.order(:code).pluck(:code, :name, :address, :type_code, :state, :state_doubtful)
        .map { |row| row[0..4] + [row[5] ? 1 : 0, InstituteName.shorten(row[1])] },
      choices: choices.joins(:institute, :program).order(:sr).pluck(:id, "institutes.code", "programs.code", :quota),
      contacts: InstituteContact.catalog_map
    }.to_json
  end
end
