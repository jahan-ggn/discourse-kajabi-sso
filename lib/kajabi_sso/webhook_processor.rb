# frozen_string_literal: true

module KajabiSso
  class WebhookProcessor
    def self.process(payload)
      new(payload).process
    end

    def initialize(payload)
      @payload = payload
    end

    def process
      email = extract_email
      offer_id = extract_offer_id&.to_s
      name = extract_name

      return Result.new(success: false, error: "missing email") if email.blank?
      return Result.new(success: false, error: "missing offer_id") if offer_id.blank?

      user = find_or_provision_user(email, name)
      unless user.persisted?
        return(Result.new(success: false, error: user.errors.full_messages.join(", ")))
      end

      UserActivator.activate!(user)
      GroupSyncService.add_for_offer(user, offer_id)
      UserTracker.track!(user)

      Result.new(success: true)
    end

    private

    def extract_email
      @payload["member_email"] || @payload.dig("member", "email")
    end

    def extract_offer_id
      @payload["offer_id"] || @payload.dig("offer", "id")
    end

    def extract_name
      @payload["member_name"] || @payload.dig("member", "name")
    end

    def find_or_provision_user(email, name)
      User.find_by_email(email) || UserProvisioner.provision(email, name: name)
    end
  end
end
