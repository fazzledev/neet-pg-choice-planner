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

  desc "Find map coordinates for institutes still missing from data/institute_locations.json"
  task geocode: :environment do
    $stdout.sync = true
    counselling = Counselling.find_by!(active: true)
    institutes = counselling.institutes.order(:code).map { { code: _1.code, name: _1.name, address: _1.address, state: _1.state_doubtful ? nil : _1.state } }
    found = InstituteGeocoder.new(Rails.root.join("data/institute_locations.json"), institutes).run
    puts "#{found.values.compact.size} of #{found.size} institutes located"
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
