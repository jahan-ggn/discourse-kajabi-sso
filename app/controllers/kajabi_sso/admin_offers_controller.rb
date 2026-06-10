# frozen_string_literal: true

module KajabiSso
  class AdminOffersController < ::Admin::AdminController
    requires_plugin PLUGIN_NAME

    def index
      unless Configuration.credentials_present?
        return render json: { error: "not configured" }, status: :unprocessable_content
      end

      client = api_client
      offers = client.offers

      render json: { offers: offers }
    rescue ApiError => e
      render json: { error: e.message }, status: :unprocessable_content
    end

    private

    def api_client
      @api_client ||=
        ApiClient.new(
          authenticator:
            ApiAuthenticator.new(
              client_id: SiteSetting.kajabi_client_id,
              client_secret: SiteSetting.kajabi_client_secret,
              base_uri: ApiClient::BASE_URI,
            ),
        )
    end
  end
end
