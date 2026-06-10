# frozen_string_literal: true

module Jobs
  class ProcessKajabiWebhook < ::Jobs::Base
    sidekiq_options retry: 3

    def execute(args)
      payload = args["payload"]
      return if payload.blank?

      processor = KajabiSso::WebhookProcessor.new
      result = processor.process(payload)

      unless result.success?
        Rails.logger.warn("[KajabiSSO] Async webhook processing failed: #{result.error}")
      end
    end
  end
end
