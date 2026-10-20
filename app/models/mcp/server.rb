module Mcp
  class Server
    MODERN_VERSIONS = %w[2026-07-28].freeze
    LEGACY_VERSIONS = %w[2025-11-25 2025-06-18 2025-03-26].freeze
    SUPPORTED_VERSIONS = (MODERN_VERSIONS + LEGACY_VERSIONS).freeze
    VERSION_META = "io.modelcontextprotocol/protocolVersion".freeze
    SERVER_INFO_META = "io.modelcontextprotocol/serverInfo".freeze
    BASE64_HEADER = /\A=\?base64\?(.*)\?=\z/
    LIST_TTL = 1.hour
    INFO = { name: "neet-pg-choice-planner", title: "NEET PG Choice Planner", version: "1.0.0" }.freeze

    INSTRUCTIONS = <<~TEXT.squish.freeze
      NEET PG Choice Planner holds the student's ranked plan of counselling choices. A choice is one institute, course and quota.
      Position 1 is the first preference. This is only a plan: the student copies it to the MCC portal with the planner's Chrome extension,
      so nothing here fills, saves or locks choices on MCC. Use list_filters for exact filter values, search_choices to find choice_ids,
      and get_plan before reordering. Ask the student before removing choices or replacing the whole plan. Every change is kept in the
      planner's history and can be restored there. This server has no cutoffs, ranks, fees or seat counts; don't invent them.
    TEXT

    def initialize(grant:, headers:)
      @tools = Tools.new(grant)
      @headers = headers
    end

    def handle(message)
      return [400, error(nil, -32600, "Send one JSON-RPC 2.0 request")] unless message.is_a?(Hash) && message["jsonrpc"] == "2.0" && message["method"].is_a?(String)
      return [202, nil] unless message.key?("id")

      params = message["params"].is_a?(Hash) ? message["params"] : {}
      version = params.dig("_meta", VERSION_META)
      version ? modern(message["id"], message["method"], params, version) : legacy(message["id"], message["method"], params)
    end

    private

    def modern(id, method, params, version)
      return [400, error(id, -32022, "Unsupported protocol version", { supported: SUPPORTED_VERSIONS, requested: version })] unless MODERN_VERSIONS.include?(version)

      mismatch = header_mismatch(method, params, version)
      return [400, error(id, -32020, "Header mismatch: #{mismatch}")] if mismatch

      case method
      when "server/discover" then [200, result(id, discover.merge(ttlMs: LIST_TTL.in_milliseconds, cacheScope: "public"), modern: true)]
      when "tools/list" then [200, result(id, { tools: Tools::DEFINITIONS, ttlMs: LIST_TTL.in_milliseconds, cacheScope: "public" }, modern: true)]
      when "tools/call" then call_tool(id, params, modern: true)
      else [404, error(id, -32601, "Method not found: #{method}")]
      end
    end

    def legacy(id, method, params)
      case method
      when "initialize" then [200, result(id, initialize_result(params["protocolVersion"]))]
      when "ping" then [200, result(id, {})]
      when "server/discover" then [200, result(id, discover)]
      when "tools/list" then [200, result(id, { tools: Tools::DEFINITIONS })]
      when "tools/call" then call_tool(id, params)
      else [200, error(id, -32601, "Method not found: #{method}")]
      end
    end

    def initialize_result(requested)
      {
        protocolVersion: LEGACY_VERSIONS.include?(requested) ? requested : LEGACY_VERSIONS.first,
        capabilities: { tools: { listChanged: false } },
        serverInfo: INFO,
        instructions: INSTRUCTIONS
      }
    end

    def discover
      { supportedVersions: SUPPORTED_VERSIONS, capabilities: { tools: { listChanged: false } }, instructions: INSTRUCTIONS }
    end

    def call_tool(id, params, modern: false)
      outcome = @tools.call(params["name"], params["arguments"])
      return [200, error(id, -32602, "Unknown tool: #{params["name"]}")] unless outcome

      [200, result(id, outcome, modern: modern)]
    end

    def header_mismatch(method, params, version)
      return "MCP-Protocol-Version must be #{version}" unless @headers["MCP-Protocol-Version"] == version
      return "Mcp-Method must be #{method}" unless @headers["Mcp-Method"] == method
      return "Mcp-Name must be #{params["name"]}" if method == "tools/call" && decode_header(@headers["Mcp-Name"]) != params["name"]

      nil
    end

    def decode_header(value)
      encoded = value.to_s[BASE64_HEADER, 1]
      encoded ? Base64.strict_decode64(encoded).force_encoding("UTF-8") : value
    rescue ArgumentError
      nil
    end

    def result(id, payload, modern: false)
      payload = payload.merge(resultType: "complete", _meta: { SERVER_INFO_META => INFO }) if modern
      { jsonrpc: "2.0", id: id, result: payload }
    end

    def error(id, code, message, data = nil)
      { jsonrpc: "2.0", id: id, error: { code: code, message: message, data: data }.compact }
    end
  end
end
