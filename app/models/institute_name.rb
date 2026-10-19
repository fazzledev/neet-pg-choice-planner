module InstituteName
  PIN = /(?<!\d)\d{6}(?!\d)/
  ASIDE = /\s*\(\s*(?:formerly|previously|prev\b\.?|erstwhile|an? unit|unit of)[^()]*\)/i
  UNIT_OF = /\s*\(?\s*\b(?:an? unit of|formerly known as|formerly|previously known as)\b.*\z/i
  INSTITUTION_END = /\A.*\b(?:Hospitals?|College|Cent(?:re|er)|Institute|Clinic|Nursing Home|Limited|Ltd\.?)/i
  ADDRESS_START = /\s*(?:,|\b(?:house|plot|door|d\.?\s?no|no\.\s*\d|sector|near|opp(?:osite)?|road|rd\.?|#\d)\b).*\z/i
  MAX_HEAD = 48
  MAX_CITY = 24

  CITY_NAMES = (Places::CITIES.values.flatten + %w[Mumbai Chennai Bangalore Bengaluru Hyderabad Kolkata Thiruvananthapuram Kochi Panaji] + ["Navi Mumbai", "New Delhi"] - %w[Uttaranchal TamilNadu T.N UP U.P]).select { _1.length > 3 }.uniq.freeze

  def self.shorten(name)
    name = name.to_s.squish
    parts = name.split(",").map(&:strip).reject(&:empty?)
    return name unless name.match?(PIN) || parts.size > 3 || name.length > 60

    head = head_of(parts)
    city = city_in(name, parts)
    short = city && !head.downcase.include?(city.downcase) ? "#{head}, #{city}" : head
    short.length < name.length ? short : name
  end

  def self.head_of(parts)
    head = parts.first.to_s
    rest = parts.drop(1)
    head = "#{head}, #{rest.shift}" while head.count("(") > head.count(")") && rest.any?
    head = head.gsub(ASIDE, "").sub(UNIT_OF, "").squish
    head = head.gsub(/\s*\([^()]*\)/, "").squish if head.length > MAX_HEAD
    head = head.sub(ADDRESS_START, "") if head.length > MAX_HEAD || head.match?(PIN) || parts.join(",").match?(PIN)
    head = head[0, 72][INSTITUTION_END] || head if head.length > MAX_HEAD
    head.sub(PIN, "").sub(/[-,(\s]+\z/, "")
  end

  def self.city_in(name, parts)
    known = CITY_NAMES.filter_map { |c| (at = name.rindex(/(?<![A-Za-z])#{Regexp.escape(c)}(?![A-Za-z])/i)) && [at, name[at, c.length]] }
    return tidy(known.max_by(&:first).last) if known.any?

    before_pin = parts.reverse.drop_while { |part| part.match?(PIN) || Places::STATES.any? { |s| part.casecmp?(s) } }.first
    candidate = before_pin && tidy(before_pin)
    candidate if candidate && candidate.length <= MAX_CITY && candidate !~ /\d/ && parts.first != before_pin
  end

  def self.tidy(text)
    text = text.sub(/[.\s]+\z/, "").squish
    text == text.upcase && text.length > 3 ? text.split.map(&:capitalize).join(" ") : text
  end
end
