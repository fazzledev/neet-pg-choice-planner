class Program < ApplicationRecord
  belongs_to :counselling
  has_many :choices, dependent: :destroy

  before_validation :classify, if: :name_changed?
  validates :code, :name, :course, :speciality, presence: true

  def classify
    course, speciality = ProgramName.classify(name)
    self.course = course || "Other"
    self.speciality = speciality || name
  end
end
