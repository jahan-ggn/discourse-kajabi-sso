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
      if offer_id.blank?
        return Result.new(success: false, error: "missing offer_id")
      end

      user = find_or_provision_user(email, name)
      unless user.persisted?
        return(
          Result.new(
            success: false,
            error: user.errors.full_messages.join(", ")
          )
        )
      end

      UserActivator.activate!(user)

      offer_ids = fetch_all_offer_ids(email) | [offer_id]
      GroupSyncService.sync(user, offer_ids)
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

    def fetch_all_offer_ids(email)
      Array(MembershipResolver.resolve(email)[:offer_ids])
    end
  end
end
