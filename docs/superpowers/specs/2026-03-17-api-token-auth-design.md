# API Token Authentication for ActiveAdmin MCP

## Overview

Add opt-in API token authentication to the MCP endpoint. Users generate tokens via an ActiveAdmin page, and MCP clients send them as Bearer tokens in the Authorization header. Tokens are hashed (SHA256) at rest. Authentication piggybacks on the host app's existing Devise user model.

## Data Model

### `mcp_api_tokens` table

| Column | Type | Notes |
|---|---|---|
| `id` | bigint | PK |
| `user_id` | bigint | FK to Devise user model, indexed, not null |
| `token_digest` | string | SHA256 hash of raw token, not null, unique index |
| `name` | string | User-provided label (e.g., "Claude Code laptop"), nullable |
| `last_used_at` | datetime | Updated on each authenticated request (throttled to once per 5 minutes), nullable |
| `created_at` | datetime | Rails timestamp |
| `updated_at` | datetime | Rails timestamp |

### `ActiveAdminMcp::ApiToken` model

- `belongs_to :user` — user class is configurable (defaults to `"User"`)
- On create: generates `SecureRandom.hex(32)` raw token with `aamcp_` prefix for identifiability, stores `Digest::SHA256.hexdigest(raw_token)` as `token_digest`
- Raw token exposed via transient `attr_accessor :raw_token`, accessible only once after creation, never persisted
- Lookup: `find_by(token_digest: Digest::SHA256.hexdigest(provided_token))`

**Security note:** Token lookup uses a database `WHERE` equality on the SHA256 digest. This is timing-safe because the comparison is on an irreversible hash — an attacker cannot exploit timing differences to recover the raw token from its digest. No additional constant-time comparison is needed for the DB lookup path. If any future code adds in-Ruby comparison of raw tokens, it must use `ActiveSupport::SecurityUtils.secure_compare`.

## Configuration

```ruby
ActiveAdminMcp.configure do |config|
  config.authentication_enabled = true
  config.user_class = "User"  # default
end
```

- `authentication_enabled` — defaults to `false` (opt-in). When false, MCP endpoint is open as today.
- `user_class` — string name of the Devise model class. Defaults to `"User"`. Used for the `belongs_to` association on `ApiToken`.

## Authentication Flow

In `McpController`:

1. `before_action :authenticate_mcp_token!` — only runs when `authentication_enabled` is `true`
2. Extracts token from `Authorization: Bearer <token>` header
3. Looks up `ApiToken` by `token_digest: Digest::SHA256.hexdigest(raw_token)`
4. **Found:** sets `current_mcp_user` accessor, touches `last_used_at` (throttled — only if nil or older than 5 minutes), proceeds
5. **Not found / missing header:** returns JSON-RPC error (`-32000`, "Unauthorized") with HTTP 401
6. **Table missing** (`ActiveRecord::StatementInvalid`): rescued in `before_action`, returns JSON-RPC error (`-32000`, "Authentication not configured — run migrations") with HTTP 500

Stateless — no cookies or sessions. Works for both POST requests and future GET-based SSE transport, since `before_action` applies to all controller actions.

## ActiveAdmin Token Management Page

A template file copied to `app/admin/mcp_api_tokens.rb` during installation. ActiveAdmin auto-loads files in `app/admin/`, so no programmatic registration method is needed.

This is an ActiveAdmin **Page** (not a Resource), so it will not be discovered by `ResourceRegistry` and `token_digest` will not be exposed through MCP tools.

- **Index view:** Table of the current user's tokens — name, created at, last used at, revoke button. Uses `current_admin_user` (Devise's standard helper available in ActiveAdmin controllers) to scope queries.
- **Create action:** Form with `name` field. On submit, generates token and displays raw token once in a flash/panel with copy warning. User warned it won't be shown again. Uses standard ActiveAdmin form submissions (CSRF handled automatically by ActionController::Base).
- **Revoke action:** Deletes token record with confirmation prompt.
- **Scoped to current user** — admins only see/manage their own tokens.

## Generator & Migration

Updated `rails generate active_admin_mcp:install` will:

1. Copy migration to create `mcp_api_tokens` table (with unique index on `token_digest`, index on `user_id`)
2. Copy initializer template to `config/initializers/active_admin_mcp.rb`
3. Copy ActiveAdmin page template to `app/admin/mcp_api_tokens.rb`
4. Print post-install instructions

The generator declares `source_root File.expand_path("templates", __dir__)` to resolve template paths.

## File Changes

### New files

- `app/models/active_admin_mcp/api_token.rb` — token model
- `lib/generators/active_admin_mcp/install/templates/migration.rb` — migration template
- `lib/generators/active_admin_mcp/install/templates/initializer.rb` — config initializer template
- `lib/generators/active_admin_mcp/install/templates/mcp_api_tokens.rb` — ActiveAdmin page template

### Modified files

- `lib/active_admin_mcp.rb` — configuration module
- `app/controllers/active_admin_mcp/mcp_controller.rb` — `before_action` auth check with missing-table rescue
- `lib/generators/active_admin_mcp/install/install_generator.rb` — add `source_root`, copy migration, initializer, admin page

### No new gem dependencies

SHA256 and SecureRandom are Ruby stdlib.

## Out of Scope

- Cookie/session handling
- Token expiry
- Rate limiting
- Scoped permissions per token
