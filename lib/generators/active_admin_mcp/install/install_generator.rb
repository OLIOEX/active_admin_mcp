# frozen_string_literal: true

module ActiveAdminMcp
  module Generators
    class InstallGenerator < Rails::Generators::Base
      desc "Shows MCP setup instructions"

      def show_instructions
        say ""
        say "=" * 60, :green
        say " ActiveAdminMcp installed!", :green
        say "=" * 60, :green
        say ""
        say "Your MCP server is available at: /mcp"
        say ""
        say "Connect Claude Code:"
        say ""
        say "  claude mcp add --transport http #{app_name} http://localhost:3000/mcp/"
        say ""
      end

      private

      def app_name
        Rails.application.class.module_parent_name.underscore.dasherize
      rescue StandardError
        "my-app"
      end
    end
  end
end
