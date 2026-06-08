# frozen_string_literal: true

module KajabiSso
  module UsersControllerExtension
    def email_login
      if KajabiSso::Configuration.enabled? && request.post? && params[:login].present?
        unless KajabiSso::Configuration.valid_credentials?
          return(
            render json: {
                     success: false,
                     error: I18n.t("kajabi_sso.misconfigured"),
                   },
                   status: :unprocessable_content
          )
        end

        result = KajabiSso::LoginPipeline.call(params[:login])

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
