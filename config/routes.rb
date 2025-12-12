# frozen_string_literal: true

ActiveAdminMcp::Engine.routes.draw do
  post "/", to: "mcp#call"
end
