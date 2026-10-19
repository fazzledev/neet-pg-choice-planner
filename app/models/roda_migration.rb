class RodaMigration
  def initialize(db_path, email:, counselling: Counselling.current)
    @old = SQLite3::Database.new(db_path, readonly: true)
    @old.results_as_hash = true
    @email = email
    @counselling = counselling
  end

  def run
    keys = @old.execute("SELECT id, instcd, brcd, quota FROM choices").to_h { [_1["id"], [_1["instcd"], _1["brcd"], _1["quota"]]] }
    lookup = @counselling.choices.joins(:institute, :program).pluck("institutes.code", "programs.code", :quota, :id).to_h { [_1[0..2], _1[3]] }
    translate = ->(picks) { picks.filter_map { |p| (id = lookup[keys[p["choice_id"]]]) && { "choice_id" => id, "note" => p["note"].to_s } } }

    current = @old.execute("SELECT choice_id, note FROM picks ORDER BY position")
    moved = translate.(current)
    raise "#{current.size - moved.size} of #{current.size} picks have no match in the new catalog" unless moved.size == current.size

    user = User.for_email(@email)
    list = user.choice_list_for(@counselling)
    ChoiceList.transaction do
      list.snapshots.delete_all
      @old.execute("SELECT created_at, label, picks FROM snapshots ORDER BY id").each do |row|
        list.snapshots.create!(label: row["label"], picks: translate.(JSON.parse(row["picks"])), created_at: Time.parse("#{row["created_at"]} UTC"))
      end
      list.replace_picks!(moved, label: "Moved from the first version of the planner")
    end
    list
  end
end
