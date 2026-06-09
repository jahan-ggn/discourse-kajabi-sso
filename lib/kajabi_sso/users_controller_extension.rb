# frozen_string_literal: true

module KajabiSso
  module UsersControllerExtension
    def email_login
      if KajabiSso::Configuration.enabled? && request.post? && params[:login].present?
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
