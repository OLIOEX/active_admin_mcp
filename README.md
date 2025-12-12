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
- [ ] Authentication (API token, HTTP Basic)
- [ ] Configurable resource allowlist
- [ ] Write operations (create, update, delete)
- [ ] Custom tool definitions per resource
- [ ] Rate limiting

## License

MIT
