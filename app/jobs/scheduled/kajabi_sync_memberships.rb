# frozen_string_literal: true

require_relative "../../../lib/kajabi_sso/errors"

module Jobs
  class KajabiSyncMemberships < ::Jobs::Scheduled
    every 6.hours

    def execute(args)
      return unless should_run?

      managed_group_ids = KajabiSso::Mappings.managed_group_ids
      return if managed_group_ids.blank?

      KajabiSso::UsersQuery
        .to_sync(managed_group_ids)
        .find_each do |user|
          begin
            sync_user(user)
          rescue KajabiSso::ApiError, KajabiSso::CircuitOpenError => e
            Rails.logger.warn("[KajabiSSO] Scheduled sync failed for #{user.email}: #{e.message}")
          end
        end
    end

    private

    def should_run?
      KajabiSso::Configuration.enabled? && KajabiSso::Configuration.credentials_present?
    end

    def sync_user(user)
      result = KajabiSso::MembershipResolver.resolve(user.email)
      KajabiSso::GroupSyncService.sync(user, result.offer_ids)
    end
  end
end
