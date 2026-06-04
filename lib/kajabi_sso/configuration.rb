# frozen_string_literal: true

module KajabiSso
  module Configuration
    def self.enabled?
      SiteSetting.kajabi_sso_enabled
    end

    def self.valid_credentials?
      SiteSetting.kajabi_client_id.present? && SiteSetting.kajabi_client_secret.present?
    end
  end
end
