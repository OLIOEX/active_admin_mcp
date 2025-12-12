# frozen_string_literal: true

module ActiveAdminMcp
  class McpController < ActionController::API
    def call
      request_body = JSON.parse(request.body.read)
      response = RequestHandler.new.handle(request_body)

      response ? render(json: response) : head(:no_content)
    rescue JSON::ParserError => e
      render json: { jsonrpc: "2.0", error: { code: -32_700, message: e.message } }, status: :bad_request
    end
  end
end
