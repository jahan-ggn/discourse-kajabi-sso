# frozen_string_literal: true

module KajabiSso
  class WebhookPayloadNormalizer
    SUPPORTED_EVENTS = %w[purchase.created payment.succeeded].freeze

    def self.normalize(event, payload)
      new(event, payload).normalize
    end

    def initialize(event, payload)
      @event = event
      @payload = payload
    end

    def normalize
      case @event
      when "purchase.created"
        Result.success(
          value: {
            "member_email" => extract_purchase_email,
            "member_name" => extract_purchase_name,
            "offer_id" => extract_purchase_offer_id,
          },
        )
      when "payment.succeeded"
        Result.success(
          value: {
            "member_email" => @payload.dig("member", "email"),
            "member_name" => @payload.dig("member", "name"),
            "offer_id" => @payload.dig("offer", "id")&.to_s,
          },
        )
      else
        Result.failure("unsupported event")
      end
    end

    private

    def extract_purchase_email
      inner = @payload["payload"] || @payload
      inner.dig("member", "email") || inner["member_email"]
    end

    def extract_purchase_name
      inner = @payload["payload"] || @payload
      inner.dig("member", "name") || inner["member_name"]
    end

    def extract_purchase_offer_id
      inner = @payload["payload"] || @payload
      (inner.dig("offer", "id") || inner["offer_id"])&.to_s
    end
  end
end
