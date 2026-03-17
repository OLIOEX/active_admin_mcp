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
