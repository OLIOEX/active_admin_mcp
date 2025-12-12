# frozen_string_literal: true

module ActiveAdminMcp
  class RequestHandler
    PROTOCOL_VERSION = "2025-06-18"

    def handle(request)
      id = request["id"]
      method = request["method"]
      params = request["params"] || {}

      case method
      when "initialize"
        success(id, initialize_result)
      when "notifications/initialized"
        nil
      when "tools/list"
        success(id, tools_list)
      when "tools/call"
        success(id, call_tool(params))
      when "ping"
        success(id, {})
      else
        error(id, -32_601, "Method not found: #{method}")
      end
    end

    private

    def initialize_result
      {
        protocolVersion: PROTOCOL_VERSION,
        serverInfo: { name: "active-admin-mcp", version: ActiveAdminMcp::VERSION },
        capabilities: { tools: {} },
      }
    end

    def tools_list
      {
        tools: [
          {
            name: "list_resources",
            description: "List all ActiveAdmin resources with their attributes",
            inputSchema: { type: "object", properties: {} },
          },
          {
            name: "query",
            description: "Query an ActiveAdmin resource using Ransack syntax",
            inputSchema: {
              type: "object",
              properties: {
                resource: { type: "string", description: "Resource name (e.g., 'User', 'Post')" },
                q: { type: "object", description: "Ransack query (e.g., {name_cont: 'john'})" },
                limit: { type: "integer", description: "Max records (default: 25)" },
              },
              required: ["resource"],
            },
          },
        ],
      }
    end

    def call_tool(params)
      name = params["name"]
      args = params["arguments"] || {}

      result = case name
               when "list_resources" then tool_list_resources
               when "query" then tool_query(args)
               else { error: "Unknown tool: #{name}" }
               end

      { content: [{ type: "text", text: JSON.pretty_generate(result) }] }
    end

    def tool_list_resources
      { resources: ResourceRegistry.all }
    end

    def tool_query(args)
      resource = ResourceRegistry.find(args["resource"])
      return { error: "Resource not found: #{args['resource']}" } unless resource

      limit = [args["limit"] || 25, 100].min
      q = args["q"] || {}

      records = resource[:model].ransack(q).result.limit(limit)
      { resource: resource[:name], count: records.size, records: records.as_json }
    end

    def success(id, result)
      { jsonrpc: "2.0", id: id, result: result }
    end

    def error(id, code, message)
      { jsonrpc: "2.0", id: id, error: { code: code, message: message } }
    end
  end
end
