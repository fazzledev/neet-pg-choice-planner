class Choice < ApplicationRecord
  belongs_to :counselling
  belongs_to :institute
  belongs_to :program
  has_many :picks, dependent: :restrict_with_error
end
