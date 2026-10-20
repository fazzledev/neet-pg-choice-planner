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
end
