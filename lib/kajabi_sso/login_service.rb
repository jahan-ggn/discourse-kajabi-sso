# frozen_string_literal: true

module KajabiSso
  class LoginService
    def self.perform(email)
      new(email).perform
    end

    def initialize(email)
      @email = email
    end

    def perform
      return failure(I18n.t("login.missing_user_field")) if @email.blank?

      normalized = Email.downcase(@email.strip)
      unless normalized.match?(URI::MailTo::EMAIL_REGEXP)
        return failure(I18n.t("kajabi_sso.invalid_email"))
      end

      return handle_bypass(normalized) if Configuration.bypass?(normalized)

      existing_user = User.real.find_by_email(normalized)
      return success(existing_user) if existing_user&.staff?

      result = MembershipResolver.resolve(normalized)
      return failure(I18n.t("kajabi_sso.error_not_active")) unless result[:contact_found]

      user = find_or_provision_user(normalized, result[:name])
      return failure(user.errors.full_messages.join("\n")) unless user.persisted?

      activate_and_sync(user, result[:offer_ids])
      success(user)
    end

    private

    def handle_bypass(email)
      user = find_or_provision_user(email)
      return failure(user.errors.full_messages.join("\n")) unless user.persisted?

      activate_and_sync(user, [])
      success(user)
    end

    def find_or_provision_user(email, name = nil)
      User.real.find_by_email(email) || UserProvisioner.provision(email, name: name)
    end

    def activate_and_sync(user, offer_ids)
      UserActivator.activate!(user)
      GroupSyncService.sync(user, offer_ids)
      UserTracker.track!(user)
    end

    def success(user)
      Result.new(success: true, user: user)
    end

    def failure(message)
      Result.new(success: false, error: message)
    end
  end
end
