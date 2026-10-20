require "csv"
require "json"
require "yaml"

module MccResults
  class ClosingRanks
    QUOTAS = { "ALLINDIA" => "All India", "AI" => "All India", "DNBQUOTA" => "DNB Quota", "AD" => "DNB Quota" }.freeze
    ROUNDS = %w[R1 R2 R3 STRAY SPSTRAY].freeze

    Result = Data.define(:ranks, :stats, :unmatched)

    def self.squash(text) = text.to_s.upcase.gsub(/[^A-Z0-9]/, "")

    CATEGORIES = { "OPEN" => "Open", "GEN" => "Open", "GENERAL" => "Open", "UR" => "Open", "OBC" => "OBC", "SC" => "SC", "ST" => "ST", "EWS" => "EWS" }.freeze

    def self.category(text)
      squashed = squash(text)
      base = squashed.delete_suffix("PWD")
      name = CATEGORIES.fetch(base, base)
      base == squashed ? name : "#{name} PwD"
    end

    def initialize(catalog:, courses:, allotments:)
      @catalog = catalog
      @courses = courses.to_h { |course, code| [self.class.squash(course), code] }
      @allotments = allotments
      @matcher = InstituteMatcher.new(catalog["institutes"])
      @offering = Hash.new { |hash, key| hash[key] = [] }
      catalog["choices"].each { |choice| @offering[[choice["brcd"], choice["quota"]]] << choice["instcd"] }
    end

    def build
      ranks = Hash.new { |hash, key| hash[key] = {} }
      stats = Hash.new { |hash, key| hash[key] = Hash.new(0) }
      unmatched = Hash.new(0)

      @allotments.sort.each do |path|
        year, round = File.basename(path, ".csv").split("-")
        file = "#{year}-#{round}"
        CSV.foreach(path, headers: true) do |row|
          quota = QUOTAS[self.class.squash(row["quota"])] or next
          stats[file][:rows] += 1
          code = @courses[self.class.squash(row["course"])]
          next stats[file][:course_not_in_catalog] += 1 unless code

          candidates = @offering[[code, quota]]
          next stats[file][:not_offered_now] += 1 if candidates.empty?

          match = @matcher.match(row["institute"], candidates)
          unless match
            stats[file][:institute_unmatched] += 1
            unmatched[[quota, code, row["institute"].squish[0, 120]]] += 1
            next
          end

          stats[file][:matched] += 1
          key = [match.code, code, quota].join("|")
          slot = [year.to_i, round, self.class.category(row["allotted_category"])]
          ranks[key][slot] = [ranks[key][slot].to_i, row["rank"].to_i].max
        end
      end

      Result.new(ranks:, stats:, unmatched:)
    end

    def self.serialize(ranks)
      ranks.sort.to_h do |key, slots|
        [key, slots.sort_by { |(year, round, category), _| [-year, ROUNDS.index(round), category] }.map { |(year, round, category), rank| [year, round, category, rank] }]
      end
    end
  end
end
