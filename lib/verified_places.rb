require "json"
require "net/http"

class VerifiedPlaces
  class Refused < StandardError; end

  NOMINATIM = URI("https://nominatim.openstreetmap.org/search")
  USER_AGENT = "neet-pg-choice-planner/1.0 (hey@fazzle.dev)"
  PAUSE = 1.1
  SETTLEMENT_RANK = 13
  STATE_SPELLINGS = { "Andaman & Nicobar Islands" => "Andaman and Nicobar Islands", "Jammu & Kashmir" => "Jammu and Kashmir", "Pondicherry" => "Puducherry" }.freeze
  NETWORK_ERRORS = [Net::OpenTimeout, Net::ReadTimeout, SocketError, Errno::ECONNRESET, Errno::ECONNREFUSED, OpenSSL::SSL::SSLError].freeze

  attr_reader :flags

  def initialize(final:, cache_path:, overrides: {}, log: $stdout)
    @overrides = overrides.transform_values { _1.fetch("at") }
    @final = final
    @cache_path = cache_path
    @cache = cache_path.exist? ? JSON.parse(cache_path.read) : {}
    @log = log
    @flags = []
  end

  def unused_overrides = @overrides.keys - @used_keys.to_a

  def locations
    @used_keys = Set.new
    @final.group_by { pin_key(_1) }.each_with_object({}) do |(_, rows), found|
      label = rows.map { _1["town"] }.tally.max_by { |town, count| [count, town] }.first
      district = rows.map { _1["district"] }.tally.max_by(&:last).first
      state = rows.first["state"]
      place = coordinates(label, district, state)
      check(label, state, place, rows)
      rows.each { found[_1["code"]] = place && [*place, label] }
    end
  ensure
    save
  end

  def titles = @final.to_h { [_1["code"], _1["title"]] }

  private

  def pin_key(row) = [row["state"], row["state"] == "Delhi" ? "delhi" : TownNames.key(row["town"])]

  def coordinates(label, district, state)
    key = [label, district, state].join("|")
    @used_keys << key
    return @overrides[key] if @overrides.key?(key)
    return @cache[key] if @cache.key?(key)

    query = state == "Delhi" ? "Delhi" : label
    hit = [{ q: "#{query}, #{district}, #{state}" }, { q: "#{query}, #{state}" }].lazy.map { best_hit(search(_1), state) }.find(&:itself)
    @cache[key] = hit && [hit["lat"].to_f.round(4), hit["lon"].to_f.round(4)]
    @log.puts "#{key}: #{@cache[key] || 'not found'}"
    @cache[key]
  end

  def best_hit(hits, state)
    in_state = hits.select { |h| (STATE_SPELLINGS[h.dig("address", "state")] || h.dig("address", "state")).to_s.casecmp?(state) || state == "Delhi" }
    in_state.find { _1["place_rank"].to_i >= SETTLEMENT_RANK } || in_state.first
  end

  def check(label, state, place, rows)
    @flags << { pin: label, state:, problem: "not found", codes: rows.map { _1["code"] } } unless place
  end

  def search(params)
    throttle
    uri = NOMINATIM.dup
    uri.query = URI.encode_www_form(params.merge(format: "jsonv2", countrycodes: "in", addressdetails: 1, limit: 5, "accept-language": "en"))
    response = request(uri)
    return [] if response.is_a?(Net::HTTPNotFound)
    raise Refused, "Nominatim answered #{response.code}; stopping so the remaining towns are looked up next run" unless response.is_a?(Net::HTTPSuccess)

    JSON.parse(response.body)
  end

  def request(uri, tries: 3)
    Net::HTTP.get_response(uri, "User-Agent" => USER_AGENT)
  rescue *NETWORK_ERRORS
    raise if (tries -= 1).zero?

    sleep PAUSE * 5
    retry
  end

  def throttle
    wait = @last_request ? PAUSE - (Process.clock_gettime(Process::CLOCK_MONOTONIC) - @last_request) : 0
    sleep wait if wait.positive?
    @last_request = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  end

  def save
    @cache_path.write("{\n#{@cache.sort.map { |key, place| "  #{key.to_json}: #{place.to_json}" }.join(",\n")}\n}\n")
  end
end
