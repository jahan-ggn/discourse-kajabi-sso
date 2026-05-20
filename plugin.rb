# frozen_string_literal: true

# name: discourse-kajabi-sso
# about: Kajabi membership verification and community integration for Discourse
# version: 0.0.1
# authors: Jahan Gagan
# url: https://github.com/jahan-ggn/discourse-kajabi-sso

enabled_site_setting :kajabi_sso_enabled

module ::KajabiSso
  PLUGIN_NAME = "discourse-kajabi-sso"
end

require_relative "lib/kajabi_sso/engine"
register_asset "stylesheets/common/kajabi-sso.scss"

module ::KajabiSso
  module UsersControllerExtension
    def email_login
      if SiteSetting.kajabi_sso_enabled
        if SiteSetting.kajabi_client_id.blank? || SiteSetting.kajabi_client_secret.blank?
          Rails.logger.warn("[KajabiSSO] Credentials missing; skipping verification.")
          return(
            render json: {
                     success: false,
                     error: I18n.t("kajabi_sso.misconfigured"),
                   },
                   status: :unprocessable_content
          )
        end

        params.require(:login)
        result = KajabiSso::Verifier.call(params[:login])

        return render json: { success: false, error: result[:error] } unless result[:success]
      end

      super
    end
  end
end

after_initialize { UsersController.prepend(::KajabiSso::UsersControllerExtension) }
