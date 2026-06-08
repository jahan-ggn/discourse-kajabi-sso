# frozen_string_literal: true

module KajabiSso
  module Configuration
    def self.enabled?
      SiteSetting.kajabi_sso_enabled
    end

    def self.valid_credentials?
      SiteSetting.kajabi_client_id.present? &&
        SiteSetting.kajabi_client_secret.present?
    end

    def self.bypass_domains
      return [] if SiteSetting.kajabi_bypass_domains.blank?

      SiteSetting
        .kajabi_bypass_domains
        .split(/[,|]+/)
        .map(&:strip)
        .map(&:downcase)
        .reject(&:blank?)
    end

    def self.bypass?(email)
      return false if email.blank?

      domain = email.split("@").last&.downcase
      bypass_domains.include?(domain)
    end
  end
end
