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
