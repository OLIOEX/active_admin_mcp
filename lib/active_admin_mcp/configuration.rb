# frozen_string_literal: true

module ActiveAdminMcp
  class Configuration
    attr_accessor :authentication_method, :user_class, :current_user_method, :menu_parent, :mount_path

    def initialize
      @authentication_method = nil
      @user_class = "User"
      @current_user_method = :current_admin_user
      @menu_parent = nil
      @mount_path = "/mcp"
    end

    def authentication_enabled?
      authentication_method == :devise_token
    end
  end
end
