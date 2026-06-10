# frozen_string_literal: true

module KajabiSso
  class LoginPipeline
    def initialize(
      email_validator: EmailValidator,
      bypass_policy: BypassPolicy,
      membership_resolver: MembershipResolver,
      user_activator: UserActivator,
      group_syncer: GroupSyncService,
      user_tracker: UserTracker,
      configuration: Configuration
    )
      @email_validator = email_validator
      @bypass_policy = bypass_policy
      @membership_resolver = membership_resolver
      @user_activator = user_activator
      @group_syncer = group_syncer
      @user_tracker = user_tracker
      @configuration = configuration
    end

    def self.call(email)
      new.call(email)
    end

    def call(email)
      validation = @email_validator.validate(email)
      return validation unless validation.success?

      email = validation.value
      return bypass_login(email) if @bypass_policy.call(email)

      unless @configuration.credentials_present?
        return Result.failure(I18n.t("kajabi_sso.misconfigured"))
      end

      user = UserFinder.find(email)
      return Result.success(user: user) if user&.staff?

      begin
        membership = @membership_resolver.resolve(email)
      rescue CircuitOpenError
        return Result.failure(I18n.t("kajabi_sso.api_unavailable"))
      rescue UnauthorizedError
        return Result.failure(I18n.t("kajabi_sso.invalid_credentials"))
      rescue ApiError
        return Result.failure(I18n.t("kajabi_sso.misconfigured"))
      end

      return Result.failure(I18n.t("kajabi_sso.error_not_active")) unless membership.found?

      user = UserFinder.find_or_provision(email, membership.name)
      return Result.failure(user.errors.full_messages.join("\n")) unless user.persisted?

      @user_activator.activate!(user)
      @group_syncer.sync(user, membership.offer_ids)
      @user_tracker.track!(user)

      Result.success(user: user)
    end

    private

    def bypass_login(email)
      user = UserFinder.find_or_provision(email)
      return Result.failure(user.errors.full_messages.join("\n")) unless user.persisted?

      @user_activator.activate!(user)
      @group_syncer.sync(user, [])
      @user_tracker.track!(user)

      Result.success(user: user)
    end
  end
end
