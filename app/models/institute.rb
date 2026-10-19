class Institute < ApplicationRecord
  belongs_to :counselling
  has_many :choices, dependent: :destroy

  before_save :locate_state, if: -> { name_changed? || address_changed? }

  private

  def locate_state
    self.state, self.state_doubtful = Places.locate("#{name} #{address}")
  end
end
