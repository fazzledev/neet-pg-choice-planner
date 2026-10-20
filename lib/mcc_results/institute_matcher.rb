module MccResults
  class InstituteMatcher
    Match = Data.define(:code, :score, :margin, :rule)

    PIN = /(?<!\d)\d{6}(?!\d)/
    GENERIC = %w[GOVT GOVERNMENT MEDICAL COLLEGE COLLEGES HOSPITAL HOSPITALS INSTITUTE OF AND THE SCIENCES SCIENCE RESEARCH CENTRE CENTER HEALTH CARE DISTRICT CIVIL GENERAL SUPER SPECIALITY SPECIALTY MULTI MULTISPECIALITY MULTISPECIALTY PVT LTD PRIVATE LIMITED MEMORIAL].freeze
    STATE_WORDS = Places::STATES.flat_map { _1.upcase.scan(/[A-Z]+/) }.uniq.freeze
    MIN_SCORE = 0.9
    MIN_MARGIN = 0.15
    PIN_BONUS = 0.35
    STATE_BONUS = 0.15

    def initialize(institutes)
      @tokens = {}
      @pins = {}
      @states = {}
      @names = {}
      @address_names = {}
      @address_words = {}
      @lead_words = {}
      institutes.each do |institute|
        text = "#{institute["name"]} #{institute["address"]}"
        code = institute["code"]
        @tokens[code] = tokens(text)
        @pins[code] = pins(text)
        state, doubtful = Places.locate(text)
        @states[code] = state unless doubtful
        @names[code] = segments(institute["name"])
        @address_names[code] = segments(institute["address"]) - @names[code]
        @address_words[code] = own_words(institute["address"].to_s.split(",").first, min: 3)
        @lead_words[code] = own_words(institute["name"].to_s.split(",").first, min: 3)
      end
      owners = Hash.new(0)
      (@names.values + @address_names.values).each { |names| names.each { owners[_1] += 1 } }
      @names.transform_values! { |names| names.select { owners[_1] == 1 } }
      @address_names.transform_values! { |names| names.select { owners[_1] == 1 } }
      counts = Hash.new(0)
      @tokens.each_value { |words| words.each { counts[_1] += 1 } }
      @weight = counts.transform_values { |count| Math.log((@tokens.size + 1).fdiv(count)) }
      @weight.default = Math.log(@tokens.size + 1)
      @cache = {}
    end

    def match(text, candidates)
      @cache[[text, candidates]] ||= best(text.to_s, candidates)
    end

    private

    def best(text, candidates)
      state, doubtful = Places.locate(text)
      state = nil if doubtful
      allowed = candidates.reject { |code| state && @states[code] && @states[code] != state }
      by_name(text, allowed) || by_tokens(text, allowed, state)
    end

    def by_name(text, candidates)
      parts = text.split(",")
      starts = parts.each_index.map { |index| squash(parts[index..].join) }
      hits = candidates.filter_map do |code|
        later = same_institution?(parts.first, @address_words[code]) && @address_words[code].any?
        found = @names[code].select { |name| starts.any? { _1.start_with?(name) } } + @address_names[code].select { |name| later ? starts.any? { _1.start_with?(name) } : starts.first.to_s.start_with?(name) }
        length = found.map(&:length).max
        [length, code] if length
      end.sort.reverse
      top, runner_up = hits
      return unless top
      return if runner_up && runner_up.first == top.first

      Match.new(code: top.last, score: 1.0, margin: (top.first - (runner_up&.first || 0)).fdiv(top.first).round(3), rule: :name)
    end

    def by_tokens(text, candidates, state)
      words = tokens(text)
      row_pins = pins(text)
      scored = candidates.map do |code|
        [score(words, row_pins, code) + (state && @states[code] == state ? STATE_BONUS : 0), code]
      end.sort.reverse
      top, runner_up = scored
      return unless top

      margin = top.first - (runner_up&.first || 0)
      return unless top.first >= MIN_SCORE && margin >= MIN_MARGIN && (row_pins & @pins.fetch(top.last)).any?
      return unless same_institution?(text.split(",").first, @lead_words[top.last])

      Match.new(code: top.last, score: top.first.round(3), margin: margin.round(3), rule: :tokens)
    end

    def score(words, row_pins, code)
      catalog = @tokens.fetch(code)
      shared = (words & catalog).sum { @weight[_1] }
      recall = shared.fdiv([catalog.sum { @weight[_1] }, 1e-9].max)
      precision = shared.fdiv([words.sum { @weight[_1] }, 1e-9].max)
      blended = recall.zero? ? 0 : 2 * recall * precision / (recall + precision)
      blended + ((row_pins & @pins.fetch(code)).any? ? PIN_BONUS : 0)
    end

    def distinctive(segment)
      words = segment.to_s.upcase.scan(/[A-Z]+/)
      return if (words - GENERIC).none? { _1.length >= 3 }

      squashed = squash(segment)
      squashed if squashed.length >= 10
    end

    def same_institution?(lead, words)
      return true if words.empty?

      squashed = squash(lead)
      initials = lead.to_s.upcase.scan(/[A-Z]+/).map { _1[0] }.join
      words.any? { squashed.include?(_1) || initials.include?(_1) }
    end

    def segments(field)
      parts = field.to_s.split(",")
      [parts.first, parts.first(2).join(",")].filter_map { distinctive(_1) }.uniq
    end

    def own_words(text, min:)
      text.to_s.upcase.scan(/[A-Z]+/).uniq.select { _1.length >= min } - GENERIC - STATE_WORDS
    end

    def squash(text) = text.to_s.upcase.gsub(/[^A-Z0-9]/, "")

    def tokens(text)
      text.to_s.upcase.gsub(PIN, " ").scan(/[A-Z][A-Z]+/).uniq
    end

    def pins(text)
      text.to_s.scan(PIN).uniq
    end
  end
end
