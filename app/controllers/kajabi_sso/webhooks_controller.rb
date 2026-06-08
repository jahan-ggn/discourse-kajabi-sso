# frozen_string_literal: true

module KajabiSso
  class WebhooksController < ::ApplicationController
    requires_plugin PLUGIN_NAME
    skip_before_action :check_xhr, raise: false
    skip_before_action :redirect_to_login_if_required, raise: false
    skip_before_action :verify_authenticity_token, raise: false

    def membership
      return forbidden unless valid_secret?

      payload = parse_payload
      event = payload["event"] || request.headers["X-Kajabi-Event"]

      case event
      when "purchase.created"
        process_webhook(payload["payload"] || payload)
      when "payment.succeeded"
        process_webhook(
          "member_email" => payload.dig("member", "email"),
          "member_name" => payload.dig("member", "name"),
          "offer_id" => payload.dig("offer", "id")&.to_s,
        )
      else
        render json: { status: "ignored" }, status: :ok
      end
    end

    private

    def parse_payload
      body = request.body.read
      request.body.rewind
      JSON.parse(body)
    rescue JSON::ParserError
      {}
    end

    def process_webhook(payload)
      result = WebhookProcessor.process(payload)

      if result.success?
        render json: { status: "synced" }, status: :ok
      else
        render json: { error: result.error }, status: :unprocessable_content
      end
    end

    def valid_secret?
      return true if SiteSetting.kajabi_webhook_secret.blank?
      ActiveSupport::SecurityUtils.secure_compare(
        params[:secret].to_s,
        SiteSetting.kajabi_webhook_secret,
      )
    end

    def forbidden
      render json: { error: "forbidden" }, status: :forbidden
    end
  end
end
