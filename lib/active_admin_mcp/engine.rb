# frozen_string_literal: true

module ActiveAdminMcp
  class Engine < ::Rails::Engine
    isolate_namespace ActiveAdminMcp

    initializer "active_admin_mcp.mount" do |app|
      app.routes.prepend do
        mount ActiveAdminMcp::Engine => ActiveAdminMcp.config.mount_path
      end
    end
  end
end
