# frozen_string_literal: true

module KajabiSso
  class WebhooksController < ::ApplicationController
    requires_plugin PLUGIN_NAME
    skip_before_action :check_xhr, raise: false
    skip_before_action :redirect_to_login_if_required, raise: false

    def membership
      # TODO: Verify webhook signature, update membership state, clear cache.
      render json: { status: "not_implemented" }, status: :not_implemented
    end
  end
end
