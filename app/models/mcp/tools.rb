module Mcp
  class Tools
    class Invalid < StandardError; end

    SEARCH_LIMIT = 25
    SEARCH_MAX = 100
    QUERY_WORDS = 8
    PLAN_MAX = 2000
    AUTH = [{ type: "oauth2", scopes: [OauthGrant::SCOPE] }].freeze
    READ = { readOnlyHint: true, destructiveHint: false, idempotentHint: true, openWorldHint: false }.freeze
    WRITE = { readOnlyHint: false, destructiveHint: false, idempotentHint: false, openWorldHint: false }.freeze
    DESTRUCTIVE = WRITE.merge(destructiveHint: true).freeze

    CHOICE_COLUMNS = {
      choice_id: "choices.id", institute_code: "institutes.code", institute: "institutes.name", state: "institutes.state",
      institute_type: "institutes.type_name", course: "programs.course", speciality: "programs.speciality",
      program: "programs.name", program_code: "programs.code", quota: "choices.quota"
    }.freeze

    FILTER_COLUMNS = {
      "speciality" => %w[programs.speciality], "course" => %w[programs.course], "state" => %w[institutes.state],
      "institute_type" => %w[institutes.type_code institutes.type_name], "quota" => %w[choices.quota]
    }.freeze

    CHOICE_IDS = { type: "array", items: { type: "integer" }, minItems: 1, maxItems: 500, description: "choice_id values from search_choices, get_institute or get_plan" }.freeze
    POSITION = { type: "integer", minimum: 1, description: "1-based rank in the plan; 1 is the first preference" }.freeze
    FILTER_LIST = { type: "array", items: { type: "string" } }.freeze
    NO_INPUT = { type: "object", properties: {}, additionalProperties: false }.freeze

    DEFINITIONS = [
      {
        name: "list_filters", title: "List filters",
        description: "Lists the exact courses, specialities (with how many choices each has), states, institute types and quotas you can filter search_choices by.",
        inputSchema: NO_INPUT, annotations: READ
      },
      {
        name: "search_choices", title: "Search choices",
        description: "Searches the counselling's choices. Every word of query must match the institute name, address or code, or the course name or speciality. Filters take values from list_filters and match any of the listed values. Results come in MCC's order and show plan_position when the choice is already in the plan.",
        inputSchema: {
          type: "object",
          properties: {
            query: { type: "string", description: "Words such as a college, city or course, e.g. \"radiology pune\"" },
            speciality: FILTER_LIST.merge(description: "Specialities, e.g. [\"Radiodiagnosis\"]"),
            course: FILTER_LIST.merge(description: "Courses, e.g. [\"MD\", \"DNB\"]"),
            state: FILTER_LIST.merge(description: "States, e.g. [\"Karnataka\"]"),
            institute_type: FILTER_LIST.merge(description: "Institute type codes or names, e.g. [\"AIC\"]"),
            quota: FILTER_LIST.merge(description: "Quotas, e.g. [\"All India\"]"),
            exclude_planned: { type: "boolean", description: "Leave out choices already in the plan" },
            limit: { type: "integer", minimum: 1, maximum: SEARCH_MAX, description: "Results per page, #{SEARCH_LIMIT} by default" },
            offset: { type: "integer", minimum: 0, description: "Skip this many results, for the next page" }
          },
          additionalProperties: false
        },
        annotations: READ
      },
      {
        name: "get_institute", title: "Get institute",
        description: "Shows one institute with every choice it offers and, for DNB hospitals, the researched DNB coordinator contact.",
        inputSchema: { type: "object", properties: { code: { type: "string", description: "institute_code from search_choices" } }, required: ["code"], additionalProperties: false },
        annotations: READ
      },
      {
        name: "get_plan", title: "Get plan",
        description: "Returns the student's whole plan in rank order with each choice's details and note, plus the plan's revision.",
        inputSchema: NO_INPUT, annotations: READ
      },
      {
        name: "add_to_plan", title: "Add to plan",
        description: "Adds choices to the plan in the given order, at the end or starting at position. Choices already in the plan stay where they are.",
        inputSchema: { type: "object", properties: { choice_ids: CHOICE_IDS, position: POSITION.merge(description: "Rank the first added choice gets; the end of the plan by default") }, required: ["choice_ids"], additionalProperties: false },
        annotations: WRITE
      },
      {
        name: "remove_from_plan", title: "Remove from plan",
        description: "Removes choices from the plan. Ask the student first.",
        inputSchema: { type: "object", properties: { choice_ids: CHOICE_IDS }, required: ["choice_ids"], additionalProperties: false },
        annotations: DESTRUCTIVE
      },
      {
        name: "move_in_plan", title: "Move in plan",
        description: "Moves choices already in the plan so they sit together in the given order, the first one landing at position.",
        inputSchema: { type: "object", properties: { choice_ids: CHOICE_IDS, position: POSITION }, required: %w[choice_ids position], additionalProperties: false },
        annotations: WRITE
      },
      {
        name: "set_note", title: "Set note",
        description: "Sets the student's note on a choice in the plan, up to #{ChoiceList::NOTE_LIMIT} characters. An empty note clears it.",
        inputSchema: { type: "object", properties: { choice_id: { type: "integer" }, note: { type: "string", maxLength: ChoiceList::NOTE_LIMIT } }, required: %w[choice_id note], additionalProperties: false },
        annotations: WRITE.merge(idempotentHint: true)
      },
      {
        name: "replace_plan", title: "Replace plan",
        description: "Replaces the whole plan with choice_ids in this order, keeping notes on choices that stay. Use it for big reorders, after showing the student the new order. Pass base_revision from get_plan to fail if the plan changed meanwhile.",
        inputSchema: {
          type: "object",
          properties: { choice_ids: CHOICE_IDS.merge(minItems: 0, maxItems: PLAN_MAX), base_revision: { type: "integer", description: "revision from get_plan" } },
          required: ["choice_ids"], additionalProperties: false
        },
        annotations: DESTRUCTIVE.merge(idempotentHint: true)
      },
      {
        name: "get_profile", title: "Get profile",
        description: "Returns the signed-in student's account.",
        inputSchema: NO_INPUT,
        outputSchema: {
          type: "object",
          properties: { id: { type: "string", minLength: 1, pattern: "\\S" }, email: { type: "string" }, name: { type: "string" } },
          required: ["id"], additionalProperties: false
        },
        annotations: READ, _meta: { "openai/profile" => true }
      }
    ].map { _1.merge(securitySchemes: AUTH) }.freeze

    NAMES = DEFINITIONS.map { _1[:name] }.freeze

    def initialize(grant)
      @grant = grant
    end

    def call(name, arguments)
      return unless NAMES.include?(name)

      data = public_send(name, arguments.is_a?(Hash) ? arguments : {})
      { content: [{ type: "text", text: data.to_json }], structuredContent: data }
    rescue Invalid, ChoiceList::Invalid, ChoiceList::Conflict => error
      { content: [{ type: "text", text: error.message }], isError: true }
    end

    def list_filters(_)
      {
        counselling: counselling.name,
        courses: counselling.programs.distinct.order(:course).pluck(:course),
        specialities: counselling.choices.joins(:program).group("programs.speciality").order("programs.speciality").count.map { { speciality: _1, choices: _2 } },
        states: counselling.institutes.where.not(state: [nil, ""]).distinct.order(:state).pluck(:state),
        institute_types: counselling.institutes.distinct.order(:type_code).pluck(:type_code, :type_name).map { { code: _1, name: _2 } },
        quotas: counselling.choices.distinct.order(:quota).pluck(:quota)
      }
    end

    def search_choices(args)
      scope = counselling.choices.joins(:institute, :program)
      words(args["query"]).each do |word|
        pattern = "%#{ActiveRecord::Base.sanitize_sql_like(word)}%"
        scope = scope.where("institutes.name LIKE :pattern OR institutes.address LIKE :pattern OR institutes.code = :word OR programs.name LIKE :pattern OR programs.speciality LIKE :pattern", pattern: pattern, word: word)
      end
      FILTER_COLUMNS.each do |key, columns|
        values = strings(args[key], key).map(&:downcase)
        scope = scope.where(columns.map { "LOWER(#{_1}) IN (:values)" }.join(" OR "), values: values) if values.any?
      end
      scope = scope.where.not(id: list.picks.select(:choice_id)) if args["exclude_planned"] == true

      limit = integer(args["limit"] || SEARCH_LIMIT, "limit", 1..SEARCH_MAX)
      offset = integer(args["offset"] || 0, "offset", 0..)
      total = scope.count
      results = with_positions(choice_rows(scope.order(:sr).limit(limit).offset(offset)))
      { total: total, offset: offset, next_offset: (offset + results.size if offset + results.size < total), results: results }.compact
    end

    def get_institute(args)
      code = args["code"].to_s.strip
      institute = counselling.institutes.find_by(code: code) or raise Invalid, "No institute has code #{code.inspect}. Find codes with search_choices."
      contact = InstituteContact.find_by(institute_code: institute.code)
      {
        institute_code: institute.code, name: institute.name, short_name: InstituteTitle.for(institute.code, institute.name), address: institute.address,
        state: institute.state, state_uncertain: institute.state_doubtful, institute_type: institute.type_name,
        dnb_contact: contact&.details&.merge("researched_on" => contact.researched_on&.iso8601),
        choices: with_positions(choice_rows(institute.choices.order(:sr)))
      }.compact
    end

    def get_plan(_)
      picks = list.picks.reload.to_a
      rows = choice_rows(counselling.choices.where(id: picks.map(&:choice_id))).index_by { _1[:choice_id] }
      { revision: list.reload.revision, count: picks.size, picks: picks.map { { position: _1.position }.merge(rows.fetch(_1.choice_id), note: _1.note.to_s) } }
    end

    def add_to_plan(args)
      ids = known_choice_ids(args["choice_ids"])
      already = []
      edit_plan do |items|
        already = ids & items.map { _1["choice_id"] }
        fresh = (ids - already).map { { "choice_id" => _1, "note" => "" } }
        items.insert(position(args["position"], items.size + 1) - 1, *fresh)
      end
      plan_change(placed: ids - already, already_in_plan: already)
    end

    def remove_from_plan(args)
      ids = choice_ids(args["choice_ids"])
      missing = []
      edit_plan do |items|
        missing = ids - items.map { _1["choice_id"] }
        items.reject { ids.include?(_1["choice_id"]) }
      end
      plan_change(removed: ids - missing, not_in_plan: missing)
    end

    def move_in_plan(args)
      ids = choice_ids(args["choice_ids"])
      raise Invalid, "position is required" if args["position"].nil?

      missing = []
      edit_plan do |items|
        by_id = items.index_by { _1["choice_id"] }
        missing = ids - by_id.keys
        moving = (ids - missing).map { by_id[_1] }
        rest = items - moving
        rest.insert(position(args["position"], rest.size + 1) - 1, *moving)
      end
      plan_change(placed: ids - missing, not_in_plan: missing)
    end

    def set_note(args)
      id = integer(args["choice_id"], "choice_id", 1..)
      note = args["note"]
      raise Invalid, "note must be text" unless note.is_a?(String)

      edit_plan do |items|
        item = items.find { _1["choice_id"] == id } or raise Invalid, "Choice #{id} isn't in the plan. Add it first."
        item["note"] = note
        items
      end
      plan_change(placed: [id])
    end

    def replace_plan(args)
      ids = known_choice_ids(args["choice_ids"], allow_empty: true, max: PLAN_MAX)
      base = args["base_revision"].nil? ? nil : integer(args["base_revision"], "base_revision", 0..)
      before = []
      edit_plan(base: base) do |items|
        before = items.map { _1["choice_id"] }
        notes = items.to_h { [_1["choice_id"], _1["note"]] }
        ids.map { { "choice_id" => _1, "note" => notes[_1].to_s } }
      end
      { revision: list.revision, count: ids.size, added: (ids - before).size, removed: (before - ids).size }
    end

    def get_profile(_)
      user = @grant.user
      { id: profile_id(user), email: user.email, name: user.name.presence }.compact
    end

    private

    def counselling
      @counselling ||= Counselling.current or raise Invalid, "No counselling has been imported yet."
    end

    def list
      @list ||= @grant.user.choice_list_for(counselling)
    end

    def edit_plan(base: nil)
      attempts = 0
      begin
        list.reload
        items = list.picks.reload.map { { "choice_id" => _1.choice_id, "note" => _1.note.to_s } }
        list.replace_picks!(yield(items), base: base || list.revision, session_id: @grant.session_id)
      rescue ChoiceList::Conflict
        raise ChoiceList::Conflict, "The plan changed since base_revision #{base}. Call get_plan and try again." if base

        retry if (attempts += 1) < 3
        raise
      end
    end

    def plan_change(placed: [], **lists)
      positions = list.picks.reload.pluck(:choice_id, :position).to_h
      rows = choice_rows(counselling.choices.where(id: placed)).index_by { _1[:choice_id] }
      changed = placed.filter_map { rows[_1]&.then { |row| { position: positions[row[:choice_id]] }.merge(row) } }
      { revision: list.revision, count: positions.size, changed: changed }.merge(lists.select { _2.any? })
    end

    def choice_rows(scope)
      scope.joins(:institute, :program).pluck(*CHOICE_COLUMNS.values).map { CHOICE_COLUMNS.keys.zip(_1).to_h }
    end

    def with_positions(rows)
      positions = list.picks.pluck(:choice_id, :position).to_h
      rows.map { _1.merge(plan_position: positions[_1[:choice_id]]).compact }
    end

    def known_choice_ids(value, allow_empty: false, max: CHOICE_IDS[:maxItems])
      ids = choice_ids(value, allow_empty: allow_empty, max: max)
      unknown = ids - counselling.choices.where(id: ids).pluck(:id)
      raise Invalid, "Unknown choice_ids: #{unknown.first(20).join(", ")}. Find them with search_choices." if unknown.any?

      ids
    end

    def choice_ids(value, allow_empty: false, max: CHOICE_IDS[:maxItems])
      raise Invalid, "choice_ids must be a list of choice_id numbers" unless value.is_a?(Array) && (allow_empty || value.any?)
      raise Invalid, "choice_ids can list at most #{max}" if value.size > max

      ids = value.map { integer(_1, "choice_ids", 1..) }
      raise Invalid, "choice_ids lists a choice twice" unless ids.uniq.size == ids.size

      ids
    end

    def position(value, last)
      value.nil? ? last : integer(value, "position", 1..).clamp(1, last)
    end

    def integer(value, name, range)
      number = value.is_a?(Integer) ? value : Integer(value.to_s, 10, exception: false)
      raise Invalid, "#{name} must be a whole number in #{range}" unless number && range.cover?(number)

      number
    end

    def strings(value, name)
      return [] if value.nil?
      return [value] if value.is_a?(String)
      raise Invalid, "#{name} must be a list of strings" unless value.is_a?(Array) && value.all?(String)

      value
    end

    def words(query)
      raise Invalid, "query must be text" unless query.nil? || query.is_a?(String)

      query.to_s.split.first(QUERY_WORDS)
    end

    def profile_id(user)
      OpenSSL::HMAC.hexdigest("SHA256", Rails.application.key_generator.generate_key("mcp profile id"), user.id.to_s).first(32)
    end
  end
end
