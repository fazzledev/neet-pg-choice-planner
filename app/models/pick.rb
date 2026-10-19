class Pick < ApplicationRecord
  belongs_to :choice_list
  belongs_to :choice
end
