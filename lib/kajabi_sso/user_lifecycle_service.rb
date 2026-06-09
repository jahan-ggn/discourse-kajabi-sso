# frozen_string_literal: true

module KajabiSso
  class UserLifecycleService
    def self.apply(user, offer_ids, mode: :sync)
      new(user, offer_ids, mode: mode).apply
    end

    def initialize(user, offer_ids, mode: :sync)
      @user = user
      @offer_ids = offer_ids
      @mode = mode
    end

    def apply
      UserActivator.activate!(@user)
      sync_groups
      UserTracker.track!(@user)
    end

    private

    def sync_groups
      if @mode == :add_only
        GroupSyncService.add_for_offer(@user, @offer_ids.first)
      else
        GroupSyncService.sync(@user, @offer_ids)
      end
    end
  end
end
