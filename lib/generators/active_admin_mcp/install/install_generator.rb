# frozen_string_literal: true

require "rails/generators"
require "rails/generators/active_record"

module ActiveAdminMcp
  module Generators
    class InstallGenerator < Rails::Generators::Base
      include ActiveRecord::Generators::Migration

      source_root File.expand_path("templates", __dir__)

      class_option :auth, type: :boolean, default: false,
                          desc: "Generate authentication support (migration, admin page, config)"

      def copy_initializer
        template "initializer.rb", "config/initializers/active_admin_mcp.rb"
      end

      def copy_migration
        return unless options[:auth]

        migration_template "migration.rb.erb", "db/migrate/create_mcp_api_tokens.rb"
      end

      def copy_admin_page
        return unless options[:auth]

        copy_file "mcp_api_tokens.rb", "app/admin/mcp_api_tokens.rb"
      end

      def uncomment_auth_config
        return unless options[:auth]

        gsub_file "config/initializers/active_admin_mcp.rb",
                  "# config.authentication_method = :devise_token",
                  "config.authentication_method = :devise_token"
      end

      def show_instructions
        say ""
        say "=" * 60, :green
        say " ActiveAdminMcp installed!", :green
        say "=" * 60, :green
        say ""
        say "Your MCP server is available at: /mcp"
        say ""

        if options[:auth]
          say "Authentication enabled! Next steps:", :yellow
          say ""
          say "  1. Run migrations:"
          say "     rails db:migrate"
          say ""
          say "  2. Create tokens via ActiveAdmin:"
          say "     Log in to /admin and visit 'MCP Tokens' under Settings"
          say ""
          say "  3. Connect Claude Code with your token:"
          say "     claude mcp add --transport http \\", :cyan
          say "       --header 'Authorization: Bearer YOUR_TOKEN' \\", :cyan
          say "       #{app_name} http://localhost:3000/mcp/", :cyan
        else
          say "Connect Claude Code:"
          say ""
          say "  claude mcp add --transport http #{app_name} http://localhost:3000/mcp/"
          say ""
          say "To add authentication later:"
          say "  rails generate active_admin_mcp:install --auth"
        end

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
