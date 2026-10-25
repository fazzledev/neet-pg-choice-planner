require "test_helper"

class InstituteTitleTest < ActiveSupport::TestCase
  test "uses the verified title when the review has one" do
    assert_equal "KIMS Saveera Hospital, Anantapur", InstituteTitle.for("701355", "KIMS Saveera Hospital, #1-1348,Srinagar Colony Extention, Anantapuram")
  end

  test "falls back to the shortened official name" do
    name = "Sample Hospital, Plot 12, MG Road, Pune, Maharashtra-411001"
    assert_equal InstituteName.shorten(name), InstituteTitle.for("not-a-code", name)
  end
end
