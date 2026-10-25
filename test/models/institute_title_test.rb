require "test_helper"

class InstituteTitleTest < ActiveSupport::TestCase
  test "uses the verified title when the review has one" do
    code, title = InstituteTitle.all.first
    skip "no verified titles in this checkout" unless code
    assert_equal title, InstituteTitle.for(code, "Anything, Somewhere")
  end

  test "falls back to the shortened official name" do
    name = "Sample Hospital, Plot 12, MG Road, Pune, Maharashtra-411001"
    assert_equal InstituteName.shorten(name), InstituteTitle.for("not-a-code", name)
  end
end
