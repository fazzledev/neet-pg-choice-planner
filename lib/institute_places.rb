require "json"
require "net/http"

class InstitutePlaces
  class Refused < StandardError; end

  GEONAMES_URL = "https://download.geonames.org/export/zip/IN.zip"
  NOMINATIM = URI("https://nominatim.openstreetmap.org/search")
  USER_AGENT = "neet-pg-choice-planner/1.0 (hey@fazzle.dev)"
  PAUSE = 1.1
  PIN = /(?<!\d)([1-9]\d{2})\s?(\d{3})(?!\d)/
  STATE_SPELLINGS = {
    "Andaman & Nicobar Islands" => "Andaman and Nicobar Islands",
    "Jammu & Kashmir" => "Jammu and Kashmir",
    "Pondicherry" => "Puducherry",
    "Dadra and Nagar Haveli and Daman and Diu" => "Dadra and Nagar Haveli"
  }.freeze
  CITY_SPELLINGS = {
    "bangalore" => "bengaluru", "mysore" => "mysuru", "calicut" => "kozhikode", "trichy" => "tiruchirappalli",
    "gurugram" => "gurgaon", "prayagraj" => "allahabad", "trivandrum" => "thiruvananthapuram", "cochin" => "ernakulam",
    "kochi" => "ernakulam", "baroda" => "vadodara", "belgaum" => "belagavi", "gulbarga" => "kalaburagi",
    "shimoga" => "shivamogga", "bellary" => "ballari", "new delhi" => "new delhi", "navi mumbai" => "thane"
  }.freeze
  KNOWN_CITIES = Places::ALIASES.transform_keys(&:downcase).except(*Places::AMBIGUOUS.map(&:downcase)).freeze
  STATE_WORDS = (Places::STATES + %w[Orissa Pondicherry Uttaranchal]).map { _1.downcase.delete(" ") }.to_set.freeze
  DISTRICT_SPELLINGS = {
    "Ananthnag" => "Anantnag", "Jhujhunu" => "Jhunjhunu", "Surendra Nagar" => "Surendranagar", "Darjiling" => "Darjeeling", "K.V.Rangareddy" => "Rangareddy", "Karim Nagar" => "Karimnagar", "Mahabub Nagar" => "Mahabubnagar",
    "Gandhi Nagar" => "Gandhinagar", "Ganganagar" => "Sri Ganganagar", "Ahmed Nagar" => "Ahmednagar",
    "South Dinajpur" => "Balurghat", "North Dinajpur" => "Raiganj"
  }.freeze
  FAR_FROM_DISTRICT_KM = 100
  SETTLEMENT_RANK = 13
  LADAKH_DISTRICTS = %w[Leh Kargil].freeze
  CITY_STATES = %w[Delhi Chandigarh Puducherry].freeze
  NETWORK_ERRORS = [Net::OpenTimeout, Net::ReadTimeout, SocketError, Errno::ECONNRESET, Errno::ECONNREFUSED, OpenSSL::SSL::SSLError].freeze

  def initialize(geonames_path, cache_path, log: $stdout)
    @geonames_path = geonames_path
    @cache_path = cache_path
    @log = log
    @cache = cache_path.exist? ? JSON.parse(cache_path.read) : {}
  end

  def locate(institutes)
    areas = institutes.to_h { [_1[:code], area_for(_1)] }
    labels = areas.values.compact.group_by { _1[:key] }.transform_values { |list| label_for(list) }
    areas.each_with_object({}) do |(code, area), found|
      next found[code] = nil unless area

      label, state = labels.fetch(area[:key])
      district = area[:district] && tidy(area[:district])
      place = coordinates(label, state, area[:district])
      label, place = district, coordinates(district, state, area[:district]) if place.nil? && district && district != label
      found[code] = place && [*place, label]
    end
  ensure
    save
  end

  private

  def area_for(inst)
    text = "#{inst[:name]} #{inst[:address]}"
    city = InstituteName.city_in(text, text.split(",").map(&:strip))
    city ||= inst[:states].first if inst[:states].one? && CITY_STATES.include?(inst[:states].first)
    by_pin = text.scan(PIN).map(&:join).filter_map { pincodes[_1] }.find { |state, _| inst[:states].empty? || inst[:states].include?(state) }
    state, district = by_pin || district_named(city, inst[:states]) || (district_mentioned(text, inst[:states]) unless city)
    return unless district || (city && inst[:states].one?)

    state ||= inst[:states].first
    { key: [state, district || city], state: state, district: district, city: city }
  end

  def district_named(city, states)
    return unless city

    wanted = spelling(city)
    states.each do |state|
      district = districts[state]&.find { spelling(_1) == wanted } || places.dig(state, wanted)
      return [state, district] if district
    end
    nil
  end

  def district_mentioned(text, states)
    words = spelling(text.gsub(/[^A-Za-z ]+/, " "))
    states.each do |state|
      names = districts.fetch(state, []).to_h { [spelling(_1), _1] }.merge(places.fetch(state, {}).select { |name, _| name.length >= 6 })
      found = names.keys.select { words.match?(/\b#{Regexp.escape(_1)}\b/) }.max_by(&:length)
      return [state, names[found]] if found
    end
    nil
  end

  def label_for(list)
    first = list.first
    named = list.filter_map { _1[:city] }.select { |city| first[:district].nil? || belongs?(city, first[:state], first[:district]) }
    label = named.tally.max_by { |city, count| [count, -city.length] }&.first
    label = first[:district] if label.nil? || (first[:district] && near?(label, first[:district]))
    [tidy(label), first[:state]]
  end

  def coordinates(label, state, district)
    query = "#{label}, #{state}"
    return @cache[query] if @cache.key?(query)

    hits = search(q: query, featureType: "settlement")
    hits = search(q: query) if hits.empty?
    hits = hits.sort_by.with_index { |h, i| [h["place_rank"].to_i >= SETTLEMENT_RANK ? 0 : 1, i] }
    centre = district_centres[district]
    away = ->(h) { distance(centre, [h["lat"].to_f, h["lon"].to_f]) }
    hit = centre.nil? || hits.empty? || away.(hits.first) <= FAR_FROM_DISTRICT_KM ? hits.first : hits.min_by(&away)
    @cache[query] = hit && [hit["lat"].to_f.round(4), hit["lon"].to_f.round(4)]
    @log.puts "#{query}: #{@cache[query] || 'not found'}"
    @cache[query]
  end

  def search(params)
    throttle
    uri = NOMINATIM.dup
    uri.query = URI.encode_www_form(params.merge(format: "jsonv2", countrycodes: "in", addressdetails: 1, limit: 5, "accept-language": "en"))
    response = request(uri)
    return [] if response.is_a?(Net::HTTPNotFound)
    raise Refused, "Nominatim answered #{response.code}; stopping so the remaining places are looked up next run" unless response.is_a?(Net::HTTPSuccess)

    state = params[:q].split(", ").last
    JSON.parse(response.body).select { (STATE_SPELLINGS[_1.dig("address", "state")] || _1.dig("address", "state")).to_s.casecmp?(state) }
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

  def belongs?(city, state, district)
    return false if STATE_WORDS.include?(city.downcase.delete(" "))

    other_districts = districts.fetch(state, []).map { spelling(_1) } - [spelling(district)]
    return false if other_districts.include?(spelling(city))

    found = district_named(city, [state])&.last
    return found == district if found

    KNOWN_CITIES[city.downcase] == state
  end

  def tidy(name)
    name = name.sub(/\s*\([^)]*\)\z/, "").squish
    DISTRICT_SPELLINGS.fetch(name, name)
  end

  def near?(city, district)
    DidYouMean::Levenshtein.distance(spelling(city), spelling(district)) <= 3
  end

  def spelling(name)
    key = name.downcase.sub(/\s*\((urban|rural)\)\z/, "").squish
    CITY_SPELLINGS.fetch(key, key)
  end

  def rows
    @rows ||= File.foreach(@geonames_path).map do |line|
      _, pin, place, state, _, district, _, _, _, lat, lng = line.chomp.split("\t")
      state = LADAKH_DISTRICTS.include?(district) ? "Ladakh" : STATE_SPELLINGS.fetch(state, state)
      [pin, spelling(place), state, district, lat.to_f, lng.to_f]
    end
  end

  def district_centres
    @district_centres ||= rows.group_by { _1[3] }.transform_values do |list|
      [list.map { _1[4] }.sort[list.size / 2], list.map { _1[5] }.sort[list.size / 2]]
    end
  end

  def distance(a, b)
    rad = Math::PI / 180
    h = Math.sin((b[0] - a[0]) * rad / 2)**2 + Math.cos(a[0] * rad) * Math.cos(b[0] * rad) * Math.sin((b[1] - a[1]) * rad / 2)**2
    2 * 6371 * Math.asin(Math.sqrt(h))
  end

  def pincodes
    @pincodes ||= rows.group_by(&:first).transform_values { |list| list.map { [_1[2], _1[3]] }.tally.max_by(&:last).first }
  end

  def districts
    @districts ||= rows.group_by { _1[2] }.transform_values { |list| list.map { _1[3] }.uniq }
  end

  def places
    @places ||= rows.group_by { _1[2] }.transform_values { |list| list.to_h { [_1[1], _1[3]] } }
  end

  def save
    @cache_path.write("{\n#{@cache.sort.map { |query, place| "  #{query.to_json}: #{place.to_json}" }.join(",\n")}\n}\n")
  end
end
