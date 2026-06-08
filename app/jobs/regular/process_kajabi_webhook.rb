# frozen_string_literal: true

module Jobs
  class ProcessKajabiWebhook < ::Jobs::Base
    sidekiq_options retry: 3

    def execute(args)
      Rails.logger.warn("[KajabiSSO] Webhook job started: #{args["payload"].inspect}")
      payload = args["payload"]
      return if payload.blank?

      result = KajabiSso::WebhookProcessor.process(payload)

      unless result.success?
        Rails.logger.warn("[KajabiSSO] Async webhook processing failed: #{result.error}")
      end
    end
  end
end
