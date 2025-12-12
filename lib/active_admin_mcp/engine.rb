# frozen_string_literal: true

module ActiveAdminMcp
  class Engine < ::Rails::Engine
    isolate_namespace ActiveAdminMcp

    initializer "active_admin_mcp.mount" do |app|
      app.routes.append do
        mount ActiveAdminMcp::Engine => "/mcp"
      end
    end
  end
end
