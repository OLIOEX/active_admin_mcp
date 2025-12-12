# frozen_string_literal: true

require_relative "active_admin_mcp/version"
require_relative "active_admin_mcp/resource_registry"
require_relative "active_admin_mcp/request_handler"
require_relative "active_admin_mcp/engine"

module ActiveAdminMcp
  class Error < StandardError; end
end
