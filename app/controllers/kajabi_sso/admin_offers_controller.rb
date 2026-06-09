# frozen_string_literal: true

module KajabiSso
  class AdminOffersController < ::Admin::AdminController
    requires_plugin PLUGIN_NAME

    def index
      unless Configuration.credentials_present?
        return render json: { error: "not configured" }, status: :unprocessable_content
      end

      client = ApiClient.instance
      offers = client.offers

      render json: { offers: offers }
    rescue ApiError => e
      render json: { error: e.message }, status: :unprocessable_content
    end
  end
end
