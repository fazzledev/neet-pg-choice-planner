require "test_helper"

class ChoiceListTest < ActiveSupport::TestCase
  setup do
    @counselling = import_catalog
    @list = User.create!(email: "student@example.com").choice_list_for(@counselling)
    @ids = @counselling.choices.order(:sr).limit(5).pluck(:id)
  end

  def items(ids) = ids.map { { "choice_id" => _1, "note" => "" } }

  test "replacing picks stores order, bumps revision and snapshots" do
    payload = @list.replace_picks!(items(@ids), base: 0)
    assert_equal @ids, payload[:picks].map { _1[:choice_id] }
    assert_equal 1, payload[:revision]
    assert_equal 1, @list.snapshots.count
  end

  test "the new revision is broadcast only once the outermost transaction commits" do
    ChoiceList.transaction do
      @list.replace_picks!(items(@ids))
      assert_no_turbo_stream_broadcasts @list
    end
    assert_turbo_stream_broadcasts @list, count: 1
  end

  test "a stale base is a conflict and changes nothing" do
    @list.replace_picks!(items(@ids), base: 0)
    assert_raises(ChoiceList::Conflict) { @list.replace_picks!(items(@ids.reverse), base: 0) }
    assert_equal @ids, @list.reload.picks.map(&:choice_id)
  end

  test "rejects duplicates, unknown ids and malformed payloads" do
    other = Counselling.create!(name: "Other", slug: "other")
    foreign = other.choices.create!(institute: other.institutes.create!(code: "X", name: "X"), program: other.programs.create!(code: "Y", name: "M.S. Orthopaedics"), quota: "All India")
    [items([@ids[0], @ids[0]]), items([foreign.id]), [{ "choice_id" => nil }], [1, 2], "nope"].each do |bad|
      assert_raises(ChoiceList::Invalid, bad.inspect) { @list.replace_picks!(bad) }
    end
  end

  test "rapid saves share a snapshot, later ones start a new one, labelled ones are kept" do
    @list.replace_picks!(items(@ids), label: "Imported")
    3.times { |i| @list.replace_picks!(items(@ids.rotate(i + 1)), session_id: 1) }
    assert_equal ["Imported", nil], @list.snapshots.order(:id).pluck(:label)
    @list.replace_picks!(items(@ids.reverse), session_id: 2)
    assert_equal 3, @list.snapshots.count
    @list.snapshots.where(label: nil).update_all(created_at: 6.minutes.ago)
    @list.replace_picks!(items(@ids), session_id: 2)
    assert_equal ["Imported", nil, nil, nil], @list.snapshots.order(:id).pluck(:label)
  end

  test "restore brings back a snapshot as a new revision" do
    @list.replace_picks!(items(@ids), label: "Imported")
    @list.replace_picks!(items(@ids.first(2)))
    @list.restore!(@list.snapshots.find_by(label: "Imported"))
    assert_equal @ids, @list.reload.picks.map(&:choice_id)
    assert_equal 3, @list.revision
  end
end
