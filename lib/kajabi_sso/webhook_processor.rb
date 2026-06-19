# frozen_string_literal: true

module KajabiSso
  class WebhookProcessor
    def initialize(
      user_activator: UserActivator,
      group_syncer: GroupSyncService,
      user_tracker: UserTracker
    )
      @user_activator = user_activator
      @group_syncer = group_syncer
      @user_tracker = user_tracker
    end

    def self.process(payload)
      new.process(payload)
    end

    def process(payload)
      email = extract_email(payload)
      offer_id = extract_offer_id(payload)&.to_s
      name = extract_name(payload)

      return Result.new(success: false, error: "missing email") if email.blank?
      return Result.new(success: false, error: "missing offer_id") if offer_id.blank?

      user = UserFinder.find_or_provision(email, name)
      unless user.persisted?
        return Result.new(success: false, error: user.errors.full_messages.join(", "))
      end

      @user_activator.activate!(user)
      @group_syncer.add_for_offer(user, offer_id)
      @user_tracker.track!(user)

      Result.new(success: true)
    end

    private

    def extract_email(payload)
      payload["member_email"] || payload.dig("member", "email")
    end

    def extract_offer_id(payload)
      payload["offer_id"] || payload.dig("offer", "id")
    end

    def extract_name(payload)
      payload["member_name"] || payload.dig("member", "name")
    end
  end
end
