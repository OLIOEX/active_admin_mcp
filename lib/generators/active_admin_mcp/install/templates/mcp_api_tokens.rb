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
