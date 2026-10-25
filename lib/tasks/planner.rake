namespace :planner do
  desc "Import a portal catalog export: rake planner:import_catalog[data/available_choices.json,NEET PG Medical Counselling 2026,neet-pg-2026]"
  task :import_catalog, %i[path name slug] => :environment do |_, args|
    counselling = CatalogImport.new(args.fetch(:path), name: args.fetch(:name), slug: args.fetch(:slug)).run
    puts "#{counselling.name}: #{counselling.institutes.count} institutes, #{counselling.programs.count} programs, #{counselling.choices.count} choices"
  end

  desc "Load institute contacts from a research file: rake planner:import_contacts[data/dnb_contacts.json]"
  task :import_contacts, %i[path] => :environment do |_, args|
    contacts = InstituteContact.import(args.fetch(:path, "data/dnb_contacts.json"))
    puts "#{contacts.size} institute contacts"
  end

  desc "Write map pins from the verified institute review (data/institute_review/final.jsonl)"
  task place_institutes: :environment do
    $stdout.sync = true
    review = Rails.root.join("data/institute_review")
    read = ->(path) { File.readlines(path).map { JSON.parse(_1) } }
    places = VerifiedPlaces.new(
      final: read.(review.join("final.jsonl")),
      cache_path: Rails.root.join("data/town_locations.json"),
      overrides: JSON.parse(Rails.root.join("data/town_overrides.json").read)
    )
    locations = places.locations
    InstituteLocation::PATH.write(CodeMap.dump(locations))
    places.unused_overrides.each { puts "warning: override #{_1} matched no town; check data/town_overrides.json" }
    review.join("place_flags.json").write(JSON.pretty_generate(places.flags) + "\n")
    puts "#{locations.values.compact.size} of #{locations.size} institutes pinned to #{locations.values.compact.map(&:last).uniq.size} towns; #{places.flags.size} pins flagged"
  end

  desc "Make an admin: rake planner:admin[you@example.com]"
  task :admin, %i[email] => :environment do |_, args|
    user = User.for_email(args.fetch(:email))
    user.update!(admin: true)
    puts "#{user.email} is an admin"
  end

  desc "Move a list from the Roda app's SQLite file: rake planner:migrate_roda[backups/roda.sqlite3,student@example.com]"
  task :migrate_roda, %i[path email] => :environment do |_, args|
    list = RodaMigration.new(args.fetch(:path), email: args.fetch(:email)).run
    puts "#{list.user.email}: #{list.picks.count} choices, #{list.snapshots.count} snapshots"
  end
end
