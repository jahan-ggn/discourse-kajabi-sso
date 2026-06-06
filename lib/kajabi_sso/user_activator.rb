# frozen_string_literal: true

module KajabiSso
  class UserActivator
    def self.activate!(user)
      new(user).activate!
    end

    def initialize(user)
      @user = user
    end

    def activate!
      @user.unstage! if @user.staged?
      @user.update!(active: true) unless @user.active
      @user.email_tokens.update_all(confirmed: true)
    end
  end
end
