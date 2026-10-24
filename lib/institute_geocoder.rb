require "json"
require "net/http"

class InstituteGeocoder
  ENDPOINT = URI("https://nominatim.openstreetmap.org/search")
  USER_AGENT = "neet-pg-choice-planner/1.0 (hey@fazzle.dev)"
  PAUSE = 1.1
  MIN_PLACE_RANK = 13
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
    save
    @found
  end

  private

  def locate(inst)
    attempts(inst).each do |precision, params|
      hit = search(params).find { in_state?(_1, inst[:state]) && _1["place_rank"].to_i >= MIN_PLACE_RANK }
      return [hit["lat"].to_f.round(5), hit["lon"].to_f.round(5), precision] if hit
    end
    nil
  end

  def attempts(inst)
    address = inst[:address].to_s.squish
    parts = address.split(/\s*,\s*/).reject(&:blank?)
    pincode = address[/(?<!\d)[1-9]\d{2}\s?\d{3}(?!\d)/]&.delete(" ")
    list = [["address", { q: address }], ["name", { q: [inst[:name], inst[:state]].compact_blank.join(", ") }]]
    list << ["pincode", { postalcode: pincode, country: "India" }] if pincode
    (1...parts.size - 1).each { list << ["locality", { q: parts.drop(_1).join(", ") }] }
    towns(address, inst[:state]).each { list << ["town", { q: [_1, inst[:state]].compact_blank.join(", ") }] }
    list.reject { _2[:q] == "" }.uniq { _2 }
  end

  def towns(address, state)
    known = Places::ALIASES.keys.select { address.match?(Places.pattern(_1)) && _1.length > 3 }
    words = address.scan(/[A-Za-z]{4,}/).reject { GENERIC_WORDS.include?(_1.upcase) }
    (known + words.last(2).reverse).map(&:titleize).uniq.first(3)
  end

  def search(params)
    throttle
    uri = ENDPOINT.dup
    uri.query = URI.encode_www_form(params.merge(format: "jsonv2", countrycodes: "in", addressdetails: 1, limit: 5))
    response = Net::HTTP.get_response(uri, "User-Agent" => USER_AGENT)
    response.is_a?(Net::HTTPSuccess) ? JSON.parse(response.body) : []
  rescue Net::OpenTimeout, Net::ReadTimeout, SocketError, Errno::ECONNRESET, JSON::ParserError
    []
  end

  def throttle
    wait = @last_request ? PAUSE - (Process.clock_gettime(Process::CLOCK_MONOTONIC) - @last_request) : 0
    sleep wait if wait.positive?
    @last_request = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  end

  def in_state?(hit, state)
    return true if state.blank?

    found = hit.dig("address", "state").to_s
    STATE_SPELLINGS.fetch(state, [state]).any? { found.casecmp?(_1) } || found.include?(state) || state.include?(found.presence || "\0")
  end

  def save
    File.write(@path, InstituteLocation.dump(@found))
  end
end
