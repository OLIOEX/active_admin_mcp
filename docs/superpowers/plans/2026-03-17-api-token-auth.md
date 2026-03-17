# API Token Authentication Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add opt-in Bearer token authentication to the MCP endpoint, backed by Devise user model with hashed tokens and an ActiveAdmin management page.

**Architecture:** Configuration module on `ActiveAdminMcp` with `authentication_method` and `user_class` settings. `ApiToken` model stores SHA256-hashed tokens linked to users. `McpController` gains a conditional `before_action` that validates Bearer tokens. Install generator gets `--auth` flag to conditionally scaffold migration + admin page.

**Tech Stack:** Ruby/Rails engine, ActiveAdmin, Devise (host app), SHA256 (stdlib), SecureRandom (stdlib)

---

## File Structure

| File | Action | Responsibility |
|------|--------|---------------|
| `lib/active_admin_mcp.rb` | Modify | Configuration module (`configure`, `config`) |
| `lib/active_admin_mcp/configuration.rb` | Create | Configuration class with `authentication_method` and `user_class` |
| `app/models/active_admin_mcp/api_token.rb` | Create | Token model — generation, hashing, lookup |
| `app/controllers/active_admin_mcp/mcp_controller.rb` | Modify | `before_action` auth check |
| `lib/generators/active_admin_mcp/install/install_generator.rb` | Modify | `--auth` flag, template copying |
| `lib/generators/active_admin_mcp/install/templates/initializer.rb` | Create | Initializer template |
| `lib/generators/active_admin_mcp/install/templates/migration.rb.erb` | Create | Migration template |
| `lib/generators/active_admin_mcp/install/templates/mcp_api_tokens.rb` | Create | ActiveAdmin page template |
| `README.md` | Modify | Auth documentation |

---

### Task 1: Configuration Module

**Files:**
- Create: `lib/active_admin_mcp/configuration.rb`
- Modify: `lib/active_admin_mcp.rb`

- [ ] **Step 1: Create the Configuration class**

Create `lib/active_admin_mcp/configuration.rb`:

```ruby
# frozen_string_literal: true

module ActiveAdminMcp
  class Configuration
    attr_accessor :authentication_method, :user_class

    def initialize
      @authentication_method = nil
      @user_class = "User"
    end

    def authentication_enabled?
      authentication_method == :devise_token
    end
  end
end
```

- [ ] **Step 2: Add configure/config to main module**

Modify `lib/active_admin_mcp.rb` to add:

```ruby
# frozen_string_literal: true

require_relative "active_admin_mcp/version"
require_relative "active_admin_mcp/configuration"
require_relative "active_admin_mcp/resource_registry"
require_relative "active_admin_mcp/request_handler"
require_relative "active_admin_mcp/engine"

module ActiveAdminMcp
  class Error < StandardError; end

  class << self
    def config
      @config ||= Configuration.new
    end

    def configure
      yield config
    end
  end
end
```

- [ ] **Step 3: Commit**

```bash
git add lib/active_admin_mcp/configuration.rb lib/active_admin_mcp.rb
git commit -m "feat: add configuration module with authentication_method and user_class"
```

---

### Task 2: ApiToken Model

**Files:**
- Create: `app/models/active_admin_mcp/api_token.rb`

- [ ] **Step 1: Create the ApiToken model**

Create `app/models/active_admin_mcp/api_token.rb`:

```ruby
# frozen_string_literal: true

require "digest"
require "securerandom"

module ActiveAdminMcp
  class ApiToken < ActiveRecord::Base
    self.table_name = "mcp_api_tokens"

    belongs_to :user, class_name: ActiveAdminMcp.config.user_class

    attr_accessor :raw_token

    validates :token_digest, presence: true, uniqueness: true
    validates :user_id, presence: true

    before_validation :generate_token, on: :create

    LAST_USED_THROTTLE = 5.minutes

    def self.find_by_raw_token(raw_token)
      return nil if raw_token.blank?

      find_by(token_digest: digest(raw_token))
    end

    def self.digest(raw_token)
      Digest::SHA256.hexdigest(raw_token)
    end

    def touch_last_used!
      return if last_used_at.present? && last_used_at > LAST_USED_THROTTLE.ago

      update_column(:last_used_at, Time.current)
    end

    private

    def generate_token
      self.raw_token = "aamcp_#{SecureRandom.hex(32)}"
      self.token_digest = self.class.digest(raw_token)
    end
  end
end
```

- [ ] **Step 2: Commit**

```bash
git add app/models/active_admin_mcp/api_token.rb
git commit -m "feat: add ApiToken model with SHA256 hashing and throttled last_used_at"
```

---

### Task 3: Controller Authentication

**Files:**
- Modify: `app/controllers/active_admin_mcp/mcp_controller.rb`

- [ ] **Step 1: Add before_action auth to McpController**

Replace the full content of `app/controllers/active_admin_mcp/mcp_controller.rb`:

```ruby
# frozen_string_literal: true

module ActiveAdminMcp
  class McpController < ActionController::API
    before_action :authenticate_mcp_token!

    attr_reader :current_mcp_user

    def call
      request_body = JSON.parse(request.body.read)
      response = RequestHandler.new.handle(request_body)

      response ? render(json: response) : head(:no_content)
    rescue JSON::ParserError => e
      render json: { jsonrpc: "2.0", error: { code: -32_700, message: e.message } }, status: :bad_request
    end

    private

    def authenticate_mcp_token!
      return unless ActiveAdminMcp.config.authentication_enabled?

      token = extract_bearer_token
      unless token
        render json: jsonrpc_error(-32_000, "Unauthorized"), status: :unauthorized
        return
      end

      api_token = ApiToken.find_by_raw_token(token)
      unless api_token
        render json: jsonrpc_error(-32_000, "Unauthorized"), status: :unauthorized
        return
      end

      @current_mcp_user = api_token.user
      api_token.touch_last_used!
    rescue ActiveRecord::StatementInvalid
      render json: jsonrpc_error(-32_000, "Authentication not configured — run migrations"),
             status: :internal_server_error
    end

    def extract_bearer_token
      header = request.headers["Authorization"]
      return nil unless header&.start_with?("Bearer ")

      header.delete_prefix("Bearer ")
    end

    def jsonrpc_error(code, message)
      { jsonrpc: "2.0", id: nil, error: { code: code, message: message } }
    end
  end
end
```

- [ ] **Step 2: Commit**

```bash
git add app/controllers/active_admin_mcp/mcp_controller.rb
git commit -m "feat: add Bearer token authentication to MCP controller"
```

---

### Task 4: Generator Templates

**Files:**
- Create: `lib/generators/active_admin_mcp/install/templates/initializer.rb`
- Create: `lib/generators/active_admin_mcp/install/templates/migration.rb.erb`
- Create: `lib/generators/active_admin_mcp/install/templates/mcp_api_tokens.rb`

- [ ] **Step 1: Create initializer template**

Create `lib/generators/active_admin_mcp/install/templates/initializer.rb`:

```ruby
# frozen_string_literal: true

ActiveAdminMcp.configure do |config|
  # Uncomment to enable API token authentication.
  # Requires running the auth migration first:
  #   rails generate active_admin_mcp:install --auth
  #
  # config.authentication_method = :devise_token

  # The Devise model class used for authentication.
  # config.user_class = "User"
end
```

- [ ] **Step 2: Create migration template**

Create `lib/generators/active_admin_mcp/install/templates/migration.rb.erb`:

```erb
# frozen_string_literal: true

class CreateMcpApiTokens < ActiveRecord::Migration[<%= ActiveRecord::Migration.current_version %>]
  def change
    create_table :mcp_api_tokens do |t|
      t.references :user, null: false, foreign_key: true
      t.string :token_digest, null: false
      t.string :name
      t.datetime :last_used_at

      t.timestamps
    end

    add_index :mcp_api_tokens, :token_digest, unique: true
  end
end
```

- [ ] **Step 3: Create ActiveAdmin page template**

Create `lib/generators/active_admin_mcp/install/templates/mcp_api_tokens.rb`:

```ruby
# frozen_string_literal: true

ActiveAdmin.register_page "MCP API Tokens" do
  menu label: "MCP Tokens", parent: "Settings", priority: 100

  content do
    @tokens = ActiveAdminMcp::ApiToken.where(user: current_admin_user).order(created_at: :desc)

    if flash[:mcp_raw_token]
      panel "New Token Created", class: "mcp-token-created" do
        para "Copy this token now — it will not be shown again:"
        pre flash[:mcp_raw_token], class: "mcp-raw-token"
      end
    end

    panel "Your MCP API Tokens" do
      table_for @tokens do
        column :name
        column(:created_at) { |t| l(t.created_at, format: :long) }
        column(:last_used_at) { |t| t.last_used_at ? l(t.last_used_at, format: :long) : "Never" }
        column "Actions" do |token|
          link_to "Revoke", admin_mcp_api_tokens_path(token_id: token.id),
                  method: :delete,
                  data: { confirm: "Revoke token '#{token.name}'?" },
                  class: "button small"
        end
      end

      if @tokens.empty?
        para "No tokens yet. Create one to authenticate MCP clients."
      end
    end

    panel "Create New Token" do
      active_admin_form_for :mcp_token, url: admin_mcp_api_tokens_path, method: :post do |f|
        f.inputs do
          f.input :name, as: :string, label: "Token Name", hint: "A label to identify this token (e.g., 'Claude Code laptop')"
        end
        f.actions do
          f.action :submit, label: "Generate Token"
        end
      end
    end
  end

  page_action :create, method: :post do
    token = ActiveAdminMcp::ApiToken.create!(
      user: current_admin_user,
      name: params[:mcp_token][:name].presence || "Unnamed token"
    )
    flash[:mcp_raw_token] = token.raw_token
    redirect_to admin_mcp_api_tokens_path
  end

  page_action :destroy, method: :delete do
    token = ActiveAdminMcp::ApiToken.where(user: current_admin_user).find(params[:token_id])
    token.destroy!
    flash[:notice] = "Token revoked."
    redirect_to admin_mcp_api_tokens_path
  end
end
```

- [ ] **Step 4: Commit**

```bash
git add lib/generators/active_admin_mcp/install/templates/
git commit -m "feat: add generator templates for initializer, migration, and admin page"
```

---

### Task 5: Update Install Generator

**Files:**
- Modify: `lib/generators/active_admin_mcp/install/install_generator.rb`

- [ ] **Step 1: Rewrite the install generator with --auth flag**

Replace the full content of `lib/generators/active_admin_mcp/install/install_generator.rb`:

```ruby
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
```

- [ ] **Step 2: Commit**

```bash
git add lib/generators/active_admin_mcp/install/install_generator.rb
git commit -m "feat: update install generator with --auth flag for conditional auth setup"
```

---

### Task 6: Update README

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Update README with authentication docs**

Replace the full `README.md` with:

```markdown
# ActiveAdminMcp

> **Status: Experimental / WIP**

Minimal MCP (Model Context Protocol) server for Rails apps with ActiveAdmin.

## Tested Clients

- **Claude Code** (Anthropic) - HTTP transport

## Installation

Add to your Gemfile:

```ruby
gem "active_admin_mcp"
```

Then run:

```bash
bundle install
rails generate active_admin_mcp:install
```

The MCP server is automatically mounted at `/mcp`.

## Authentication

To protect your MCP endpoint with API token authentication:

```bash
rails generate active_admin_mcp:install --auth
rails db:migrate
```

This will:
- Create the `mcp_api_tokens` table
- Add an "MCP Tokens" page to your ActiveAdmin panel
- Enable token authentication in the initializer

### Managing Tokens

1. Log in to your ActiveAdmin panel (`/admin`)
2. Navigate to **Settings > MCP Tokens**
3. Create a new token and copy it — it will only be shown once

### Connecting with a Token

```bash
claude mcp add --transport http \
  --header 'Authorization: Bearer YOUR_TOKEN' \
  my-app http://localhost:3000/mcp/
```

Or in `.mcp.json`:

```json
{
  "mcpServers": {
    "my-app": {
      "type": "http",
      "url": "http://localhost:3000/mcp/",
      "headers": {
        "Authorization": "Bearer YOUR_TOKEN"
      }
    }
  }
}
```

### Configuration

The initializer at `config/initializers/active_admin_mcp.rb`:

```ruby
ActiveAdminMcp.configure do |config|
  config.authentication_method = :devise_token
  config.user_class = "User"  # your Devise model class
end
```

| Option | Default | Description |
|--------|---------|-------------|
| `authentication_method` | `nil` | Set to `:devise_token` to enable Bearer token auth |
| `user_class` | `"User"` | The Devise model class name |

## Usage with Claude Code

```bash
claude mcp add --transport http my-app http://localhost:3000/mcp/
```

Or add to your `.mcp.json`:

```json
{
  "mcpServers": {
    "my-app": {
      "type": "http",
      "url": "http://localhost:3000/mcp/"
    }
  }
}
```

## Available Tools

| Tool | Description |
|------|-------------|
| `list_resources` | List all ActiveAdmin resources with their attributes |
| `query` | Query a resource using Ransack syntax |

### Query Examples

```
Query users where email contains "example.com"
→ query(resource: "User", q: { email_cont: "example.com" })

Find active posts from last week
→ query(resource: "Post", q: { status_eq: "active", created_at_gt: "2025-12-01" })
```

## Future Ideas

- [ ] SSE transport support for streaming
- [ ] Configurable resource allowlist
- [ ] Write operations (create, update, delete)
- [ ] Custom tool definitions per resource
- [ ] Rate limiting

## License

MIT
```

- [ ] **Step 2: Commit**

```bash
git add README.md
git commit -m "docs: add authentication setup guide to README"
```

---

### Task 7: Final Verification

- [ ] **Step 1: Verify all files exist**

Run: `find /Users/lloyd/Code/active_admin_mcp -name "*.rb" -path "*/active_admin_mcp/*" | sort`

Expected new files present:
- `app/models/active_admin_mcp/api_token.rb`
- `lib/active_admin_mcp/configuration.rb`
- `lib/generators/active_admin_mcp/install/templates/initializer.rb`
- `lib/generators/active_admin_mcp/install/templates/mcp_api_tokens.rb`

And: `find /Users/lloyd/Code/active_admin_mcp -name "*.erb" | sort`

Expected: `lib/generators/active_admin_mcp/install/templates/migration.rb.erb`

- [ ] **Step 2: Verify Ruby syntax on all files**

Run: `for f in app/models/active_admin_mcp/api_token.rb lib/active_admin_mcp/configuration.rb lib/active_admin_mcp.rb app/controllers/active_admin_mcp/mcp_controller.rb lib/generators/active_admin_mcp/install/install_generator.rb lib/generators/active_admin_mcp/install/templates/initializer.rb lib/generators/active_admin_mcp/install/templates/mcp_api_tokens.rb; do ruby -c "$f"; done`

Expected: `Syntax OK` for each file
