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

  desc "Pin every institute to its city using GeoNames pincodes and one Nominatim lookup per city"
  task locate_institutes: :environment do
    $stdout.sync = true
    geonames = Rails.root.join("tmp/geonames/IN.txt")
    unless geonames.exist?
      geonames.dirname.mkpath
      system("curl", "-sfL", InstitutePlaces::GEONAMES_URL, "-o", geonames.sub_ext(".zip").to_s, exception: true)
      system("unzip", "-o", "-q", geonames.sub_ext(".zip").to_s, "IN.txt", "-d", geonames.dirname.to_s, exception: true)
    end
    institutes = Counselling.current.institutes.order(:code).map do |inst|
      states = inst.state_doubtful ? Places.candidates("#{inst.name} #{inst.address}") : [inst.state].compact_blank
      { code: inst.code, name: inst.name, address: inst.address, states: states }
    end
    found = InstitutePlaces.new(geonames, Rails.root.join("data/city_locations.json")).locate(institutes)
    InstituteLocation::PATH.write(InstituteLocation.dump(found))
    puts "#{found.values.compact.size} of #{found.size} institutes pinned to #{found.values.compact.map(&:last).uniq.size} cities"
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
