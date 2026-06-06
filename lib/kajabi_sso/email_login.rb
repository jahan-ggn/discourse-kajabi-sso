# frozen_string_literal: true

module KajabiSso
  class EmailLogin
    MEMBERSHIP_CACHE_TTL = 30.seconds

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

      cached = read_cache(normalized)
      if cached.present?
        return handle_result(normalized, cached[:name], cached[:offer_ids], cached[:contact_found])
      end

      result = ApiClient.instance.active_member?(normalized)
      write_cache(normalized, result[:contact_found], result[:name], result[:offer_ids])
      handle_result(normalized, result[:name], result[:offer_ids], result[:contact_found])
    end

    private

    def handle_bypass(email)
      user = User.real.find_by_email(email) || UserProvisioner.provision(email)
      return failure(user.errors.full_messages.join("\n")) unless user.persisted?

      UserActivator.activate!(user)
      UserTracker.track!(user)
      success(user)
    end

    def handle_result(email, name, offer_ids, contact_found)
      return failure(I18n.t("kajabi_sso.error_not_active")) unless contact_found

      user = User.real.find_by_email(email) || UserProvisioner.provision(email, name: name)
      return failure(user.errors.full_messages.join("\n")) unless user.persisted?

      UserActivator.activate!(user)
      GroupSyncService.sync(user, offer_ids)
      UserTracker.track!(user)
      success(user)
    end

    def success(user)
      Result.new(success: true, user: user)
    end

    def failure(message)
      Result.new(success: false, error: message)
    end

    def read_cache(email)
      Rails.cache.read(cache_key(email))
    end

    def write_cache(email, contact_found, name = nil, offer_ids = nil)
      Rails.cache.write(
        cache_key(email),
        { contact_found: contact_found, name: name, offer_ids: offer_ids },
        expires_in: MEMBERSHIP_CACHE_TTL,
      )
    end

    def cache_key(email)
      db =
        begin
          RailsMultisite::ConnectionManagement.current_db
        rescue StandardError
          "default"
        end
      "#{db}:kajabi_sso:m:#{Digest::SHA256.hexdigest(email)}"
    end
  end
end
