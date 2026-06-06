# frozen_string_literal: true

module Jobs
  class KajabiSyncMemberships < ::Jobs::Scheduled
    every 6.hours

    def execute(args)
      return unless should_run?

      managed_group_ids = KajabiSso::Mappings.managed_group_ids
      return if managed_group_ids.blank?

      users_to_sync(managed_group_ids).find_each do |user|
        begin
          sync_user(user)
        rescue StandardError => e
          Rails.logger.warn("[KajabiSSO] Scheduled sync failed for #{user.email}: #{e.message}")
        end
      end
    end

    private

    def should_run?
      KajabiSso::Configuration.enabled? && KajabiSso::Configuration.valid_credentials?
    end

    def users_to_sync(group_ids)
      group_user_ids = GroupUser.where(group_id: group_ids).distinct.pluck(:user_id)
      custom_field_user_ids = UserCustomField.where(name: "kajabi_sso").distinct.pluck(:user_id)

      all_ids = (group_user_ids + custom_field_user_ids).uniq
      return User.none if all_ids.empty?

      User.real.not_suspended.where(id: all_ids)
    end

    def sync_user(user)
      result = KajabiSso::ApiClient.instance.active_member?(user.email)
      KajabiSso::GroupSyncService.sync(user, result[:offer_ids])
    end
  end
end
