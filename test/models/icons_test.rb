require "test_helper"

class IconsTest < ActiveSupport::TestCase
  test "the sprite is valid SVG and has every speciality icon" do
    sprite = Nokogiri::XML(Rails.root.join("app/assets/images/icons.svg").read, &:strict)
    ids = sprite.remove_namespaces!.xpath("//symbol").map { _1["id"] }
    assert_empty (ProgramName::ICONS.values + [ProgramName::DEFAULT_ICON]).uniq - ids
  end

  test "every speciality has an icon" do
    assert_empty ProgramName::SPECIALITIES.values.uniq - ProgramName::ICONS.keys
  end
end
