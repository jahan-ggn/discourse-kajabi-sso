# frozen_string_literal: true

module KajabiSso
  class LoginPipeline
    def self.call(email)
      new(email).call
    end

    def initialize(email)
      @email = email
    end

    def call
      validation = EmailValidator.validate(@email)
      return validation unless validation.success?

      email = validation.value
      return bypass_login(email) if BypassChecker.bypass?(email)

      user = UserFinder.find(email)
      return Result.success(user: user) if user&.staff?

      begin
        membership = MembershipResolver.resolve(email)
      rescue KajabiSso::CircuitOpenError
        return Result.failure(I18n.t("kajabi_sso.api_unavailable"))
      end

      return Result.failure(I18n.t("kajabi_sso.error_not_active")) unless membership[:contact_found]

      user = UserFinder.find_or_provision(email, membership[:name])
      return Result.failure(user.errors.full_messages.join("\n")) unless user.persisted?

      activate_and_sync(user, membership[:offer_ids])
      Result.success(user: user)
    end

    private

    def bypass_login(email)
      user = UserFinder.find_or_provision(email)
      return Result.failure(user.errors.full_messages.join("\n")) unless user.persisted?

      activate_and_sync(user, [])
      Result.success(user: user)
    end

    def activate_and_sync(user, offer_ids)
      UserActivator.activate!(user)
      GroupSyncService.sync(user, offer_ids)
      UserTracker.track!(user)
    end
  end
end
