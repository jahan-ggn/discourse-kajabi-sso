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
        handle_purchase_created(payload["payload"] || payload)
      when "payment.succeeded"
        handle_purchase_created(
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

    def handle_purchase_created(payload)
      email = payload["member_email"]
      offer_id = payload["offer_id"]&.to_s
      name = payload["member_name"]

      return bad_request("missing email") if email.blank?
      return bad_request("missing offer_id") if offer_id.blank?

      user = User.find_by_email(email) || UserProvisioner.provision(email, name: name)
      return render_error(user) unless user.persisted?

      UserActivator.activate!(user)

      offer_ids = Array(ApiClient.instance.active_member?(email)[:offer_ids]) | [offer_id]
      GroupSyncService.sync(user, offer_ids)
      UserTracker.track!(user)

      render json: { status: "synced" }, status: :ok
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

    def bad_request(msg)
      render json: { error: msg }, status: :unprocessable_content
    end

    def render_error(user)
      render json: { error: user.errors.full_messages.join(", ") }, status: :unprocessable_content
    end
  end
end
