# frozen_string_literal: true

module KajabiSso
  class EmailLogin
    MEMBERSHIP_CACHE_TTL = 5.minutes

    def self.perform(email)
      new(email).perform
    end

    def initialize(email)
      @email = email
    end

    def perform
      return failure(I18n.t("login.missing_user_field")) if @email.blank?
      Rails.logger.warn("F ====> Checking Kajabi SSO for email: #{@email}")

      normalized = Email.downcase(@email.strip)
      Rails.logger.warn("F ====> Normalized email: #{normalized}")

      unless normalized.match?(URI::MailTo::EMAIL_REGEXP)
        return failure(I18n.t("kajabi_sso.invalid_email"))
      end

      existing_user = User.real.find_by_email(normalized)
      return success(existing_user) if existing_user&.staff?

      cached = read_cache(normalized)
      if cached.present?
        return process_user(normalized, cached[:name]) if cached[:active]
        return failure(SiteSetting.kajabi_sso_error_not_active)
      end

      result = KajabiSso::ApiClient.instance.active_member?(normalized)

      if result[:active]
        write_cache(normalized, true, result[:name])
        process_user(normalized, result[:name])
      else
        write_cache(normalized, false)
        failure(SiteSetting.kajabi_sso_error_not_active)
      end
    end

    private

    def success(user)
      Result.new(success: true, user: user)
    end

    def failure(message)
      Result.new(success: false, error: message)
    end

    def read_cache(email)
      Rails.cache.read(cache_key(email))
    end

    def write_cache(email, active, name = nil)
      Rails.cache.write(
        cache_key(email),
        { active: active, name: name },
        expires_in: MEMBERSHIP_CACHE_TTL,
      )
    end

    def cache_key(email)
      db = RailsMultisite::ConnectionManagement.current_db rescue "default"
      "#{db}:kajabi_sso:m:#{Digest::SHA256.hexdigest(email)}"
    end

    def process_user(email, kajabi_name = nil)
      user = User.real.find_by_email(email)

      if user.nil?
        user = provision_user(email, kajabi_name)
        return failure(user.errors.full_messages.join("\n")) unless user.persisted?
      end

      user.unstage! if user.staged?

      unless user.active
        user.update!(active: true)
        user.email_tokens.update_all(confirmed: true)
      end

      success(user)
    end

    def provision_user(email, kajabi_name = nil)
      username = UserNameSuggester.suggest(kajabi_name.presence || email)
      name = kajabi_name.presence || email.split("@").first&.titleize || username

      user = User.new(
        email: email,
        username: username,
        name: name,
        staged: false,
        active: true,
        approved: true,
        trust_level: TrustLevel[0],
      )

      user.activate if user.save
      user
    end
  end
end
