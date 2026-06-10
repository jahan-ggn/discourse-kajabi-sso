# frozen_string_literal: true

module KajabiSso
  class EmailValidator
    def self.validate(email)
      new(email).validate
    end

    def initialize(email)
      @email = email
    end

    def validate
      return Result.failure(I18n.t("login.missing_user_field")) if @email.blank?

      normalized = @email.to_s.strip.downcase
      unless normalized.match?(URI::MailTo::EMAIL_REGEXP)
        return Result.failure(I18n.t("kajabi_sso.invalid_email"))
      end

      Result.success(value: normalized)
    end
  end
end
