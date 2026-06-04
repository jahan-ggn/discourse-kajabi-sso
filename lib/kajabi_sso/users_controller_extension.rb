# frozen_string_literal: true

module KajabiSso
  module UsersControllerExtension
    def email_login
      if KajabiSso::Configuration.enabled?
        unless KajabiSso::Configuration.valid_credentials?
          return(
            render json: {
                     success: false,
                     error: I18n.t("kajabi_sso.misconfigured"),
                   },
                   status: :unprocessable_content
          )
        end

        params.require(:login)
        result = KajabiSso::EmailLogin.perform(params[:login])
        Rails.logger.warn("[KajabiSSO] email_login result: #{result.to_h}")

        if result.failure?
          return(
            render json: { success: false, error: result.error }, status: :unprocessable_content
          )
        end
      end

      super
    end
  end
end
