require "test_helper"

class IconsTest < ActiveSupport::TestCase
  test "the sprite is valid SVG and has every speciality icon" do
    sprite = Nokogiri::XML(Rails.root.join("app/assets/images/icons.svg").read, &:strict)
    ids = sprite.remove_namespaces!.xpath("//symbol").map { _1["id"] }
    assert_empty (ProgramName::ICONS.values + [ProgramName::DEFAULT_ICON]).uniq - ids
  end

  test "the sprite has every icon the views use" do
    sprite = Nokogiri::XML(Rails.root.join("app/assets/images/icons.svg").read, &:strict)
    ids = sprite.remove_namespaces!.xpath("//symbol").map { _1["id"] }
    used = Rails.root.glob("app/views/**/*.erb").flat_map { _1.read.scan(/icon\("([a-z0-9-]+)"/).flatten }.uniq
    assert_includes used, "claude"
    assert_empty used - ids
  end

  test "every speciality has an icon" do
    assert_empty ProgramName::SPECIALITIES.values.uniq - ProgramName::ICONS.keys
  end
end
