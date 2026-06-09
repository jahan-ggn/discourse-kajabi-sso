# frozen_string_literal: true

module KajabiSso
  class WebhooksController < ::ApplicationController
    requires_plugin PLUGIN_NAME
    skip_before_action :check_xhr, raise: false
    skip_before_action :redirect_to_login_if_required, raise: false
    skip_before_action :verify_authenticity_token, raise: false

    def membership
      return rate_limited if rate_limiter && !rate_limiter.can_perform?
      rate_limiter&.performed!

      return forbidden unless valid_secret?

      event = parse_event
      normalized = WebhookPayloadNormalizer.normalize(event, parse_payload)

      if normalized.success?
        process_webhook(normalized.value)
      else
        render json: { status: "ignored" }, status: :ok
      end
    end

    private

    def parse_event
      request.headers["X-Kajabi-Event"].presence || parse_payload["event"]
    end

    def rate_limiter
      @rate_limiter ||=
        RateLimiter.new(
          nil,
          "kajabi_webhook:#{request.remote_ip}",
          10,
          60,
          error_code: "kajabi_webhook_rate_limited",
        )
    end

    def rate_limited
      render json: { error: "rate_limited" }, status: :too_many_requests
    end

    def parse_payload
      body = request.body.read
      request.body.rewind
      JSON.parse(body)
    rescue JSON::ParserError
      {}
    end

    def process_webhook(payload)
      Jobs.enqueue(:process_kajabi_webhook, payload: payload)
      render json: { status: "queued" }, status: :accepted
    end

    def valid_secret?
      if SiteSetting.kajabi_webhook_secret.blank?
        Rails.logger.warn(
          "[KajabiSSO] Webhook received but kajabi_webhook_secret is blank; accepting without verification.",
        )
        return true
      end
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
