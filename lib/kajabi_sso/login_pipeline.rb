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
      return bypass_login(email) if BypassPolicy.call(email)

      unless Configuration.credentials_present?
        return Result.failure(I18n.t("kajabi_sso.misconfigured"))
      end

      user = UserFinder.find(email)
      return Result.success(user: user) if user&.staff?

      begin
        membership = MembershipResolver.resolve(email)
      rescue KajabiSso::CircuitOpenError
        return Result.failure(I18n.t("kajabi_sso.api_unavailable"))
      rescue KajabiSso::UnauthorizedError
        return Result.failure(I18n.t("kajabi_sso.invalid_credentials"))
      end

      return Result.failure(I18n.t("kajabi_sso.error_not_active")) unless membership.found?

      user = UserFinder.find_or_provision(email, membership.name)
      return Result.failure(user.errors.full_messages.join("\n")) unless user.persisted?

      UserLifecycleService.apply(user, membership.offer_ids)
      Result.success(user: user)
    end

    private

    def bypass_login(email)
      user = UserFinder.find_or_provision(email)
      return Result.failure(user.errors.full_messages.join("\n")) unless user.persisted?

      UserLifecycleService.apply(user, [])
      Result.success(user: user)
    end
  end
end
