require "csv"

namespace :cutoffs do
  desc "Parse MCC allotment result PDFs into data/allotments CSVs: rake cutoffs:parse[2025,R1] (both optional)"
  task :parse, %i[year round] => :environment do |_, args|
    target = Rails.root.join("data/allotments")
    FileUtils.mkdir_p(target)
    MccResults::ResultPdf.all(Rails.root.join("data/raw/mcc"), year: args[:year], round: args[:round]).each do |pdf|
      year = pdf.year
      round = pdf.round
      allotments = pdf.allotments
      CSV.open(target.join("#{year}-#{round}.csv"), "w") do |csv|
        csv << MccResults::ResultPdf::FIELDS
        allotments.each { csv << _1.to_h.values }
      end

      ranks = allotments.map(&:rank)
      incomplete = allotments.count { |row| MccResults::ResultPdf::REQUIRED.any? { row.public_send(_1).empty? } }
      puts "#{year}-#{round}: #{pdf.page_count} pages, #{allotments.size} rows, ranks #{ranks.min}..#{ranks.max}, " \
        "#{incomplete} incomplete, #{allotments.map(&:quota).uniq.size} quotas, #{allotments.map(&:allotted_category).uniq.size} categories"
    end
  end

  desc "Check parsed ranks page by page against pdftotext -layout: rake cutoffs:verify[2025,R1] (both optional)"
  task :verify, %i[year round] => :environment do |_, args|
    MccResults::ResultPdf.all(Rails.root.join("data/raw/mcc"), year: args[:year], round: args[:round]).each do |pdf|
      result = MccResults::LayoutCheck.new(pdf).run
      serials = { true => ", serials 1..n", false => ", SERIALS BROKEN", nil => "" }.fetch(result.serials_consecutive)
      puts "#{pdf.year}-#{pdf.round}: #{result.pages_checked} pages checked, #{result.mismatched_pages.size} mismatched#{serials}, #{pdf.forced_splits} forced splits, #{pdf.orphan_leads} orphan leads"
      result.mismatched_pages.first(5).each { |page, parsed, layout| puts "  page #{page}: parsed #{parsed.inspect} layout #{layout.inspect}" }
    end
  end

  desc "Match parsed allotments to the catalog and write closing ranks to data/cutoffs/closing_ranks.json"
  task closing: :environment do
    catalog = JSON.parse(Rails.root.join("data/available_choices.json").read)
    courses = YAML.load_file(Rails.root.join("data/cutoffs/course_codes.yml"))
    result = MccResults::ClosingRanks.new(catalog:, courses:, allotments: Dir[Rails.root.join("data/allotments/*.csv")]).build

    Rails.root.join("data/cutoffs/closing_ranks.json").write(JSON.generate(MccResults::ClosingRanks.serialize(result.ranks)))
    report = ["| File | All India + DNB rows | Matched | Course not in catalog | Not offered now | Institute unmatched |", "|---|---|---|---|---|---|"]
    result.stats.sort.each do |file, counts|
      report << "| #{file} | #{counts[:rows]} | #{counts[:matched]} (#{(100.0 * counts[:matched] / counts[:rows]).round(1)}%) | #{counts[:course_not_in_catalog]} | #{counts[:not_offered_now]} | #{counts[:institute_unmatched]} |"
    end
    report << "" << "## Most frequent unmatched institutes" << ""
    result.unmatched.sort_by { -_2 }.first(60).each { |(quota, code, institute), count| report << "- #{count} × #{quota} #{code}: #{institute}" }
    Rails.root.join("data/cutoffs/match_report.md").write(report.join("\n") + "\n")
    puts report.first(17)
    puts "#{result.ranks.size} choices with closing ranks"
  end
end
