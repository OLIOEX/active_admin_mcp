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
