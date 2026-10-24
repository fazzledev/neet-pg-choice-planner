require "json"
require "net/http"

class InstituteGeocoder
  class Refused < StandardError; end

  ENDPOINT = URI("https://nominatim.openstreetmap.org/search")
  USER_AGENT = "neet-pg-choice-planner/1.0 (hey@fazzle.dev)"
  PAUSE = 1.1
  MIN_PLACE_RANK = 13
  PRECISIONS = %w[address locality town].freeze
  STREET_RANK = 26
  LOCALITY_RANK = 17
  NETWORK_ERRORS = [Net::OpenTimeout, Net::ReadTimeout, SocketError, Errno::ECONNRESET, Errno::ECONNREFUSED, OpenSSL::SSL::SSLError].freeze
  GENERIC_WORDS = (MccResults::InstituteMatcher::GENERIC + %w[ROAD MARG NAGAR DIST DISTRICT POST NEAR OPPOSITE SECTOR PLOT CITY TOWN] + Places::STATES.flat_map { _1.upcase.split }).to_set.freeze
  STATE_SPELLINGS = { "Delhi" => ["Delhi", "National Capital Territory of Delhi"] }.freeze

  def initialize(path, institutes, log: $stdout)
    @path = path
    @institutes = institutes
    @log = log
    @found = File.exist?(path) ? JSON.parse(File.read(path)) : {}
  end

  def run
    pending = @institutes.reject { @found.key?(_1[:code]) }
    pending.each_with_index do |inst, i|
      @found[inst[:code]] = locate(inst)
      @log.puts "#{i + 1}/#{pending.size} #{inst[:code]} #{@found[inst[:code]]&.last || 'miss'} #{inst[:name]}"
      save if (i % 10).zero?
    end
    @found
  ensure
    save
  end

  private

  def locate(inst)
    attempts(inst).each do |kind, params|
      hit = search(params).find { in_states?(_1, inst[:states]) && _1["place_rank"].to_i >= MIN_PLACE_RANK }
      return [hit["lat"].to_f.round(5), hit["lon"].to_f.round(5), precision(kind, hit["place_rank"].to_i)] if hit
    end
    nil
  end

  def precision(kind, rank)
    return "pincode" if kind == :pincode

    by_rank = if rank >= STREET_RANK then "address" elsif rank >= LOCALITY_RANK then "locality" else "town" end
    PRECISIONS[[PRECISIONS.index(by_rank), PRECISIONS.index(kind.to_s)].max]
  end

  def attempts(inst)
    address = inst[:address].to_s.squish
    parts = address.split(/\s*,\s*/).reject(&:blank?)
    pincode = address[/(?<!\d)[1-9]\d{2}\s?\d{3}(?!\d)/]&.delete(" ")
    list = [[:address, { q: address }]]
    inst[:states].each { list << [:address, { q: "#{inst[:name]}, #{_1}" }] }
    list << [:pincode, { postalcode: pincode, country: "India" }] if pincode
    (1...parts.size - 1).each { list << [:locality, { q: parts.drop(_1).join(", ") }] }
    towns(address).product(inst[:states]).each { |town, state| list << [:town, { q: "#{town}, #{state}" }] }
    list.reject { _2[:q] == "" }.uniq { _2 }
  end

  def towns(address)
    known = Places::ALIASES.keys.select { address.match?(Places.pattern(_1)) && _1.length > 3 }
    words = address.scan(/[A-Za-z]{4,}/).reject { GENERIC_WORDS.include?(_1.upcase) }
    (known + words.last(2).reverse).map(&:titleize).uniq.first(3)
  end

  def search(params)
    throttle
    uri = ENDPOINT.dup
    uri.query = URI.encode_www_form(params.merge(format: "jsonv2", countrycodes: "in", addressdetails: 1, limit: 5, "accept-language": "en"))
    response = request(uri)
    return [] if response.is_a?(Net::HTTPNotFound)
    raise Refused, "Nominatim answered #{response.code}; stopping so the remaining institutes are retried next run" unless response.is_a?(Net::HTTPSuccess)

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

  def in_states?(hit, states)
    return true if states.empty?

    found = hit.dig("address", "state").to_s
    states.any? { |state| STATE_SPELLINGS.fetch(state, [state]).any? { found.casecmp?(_1) } || found.include?(state) || state.include?(found.presence || "\0") }
  end

  def save
    File.write(@path, InstituteLocation.dump(@found))
  end
end
