# frozen_string_literal: true

module Jobs
  class KajabiSyncMemberships < ::Jobs::Scheduled
    every 10.minutes

    def execute(args)
      return unless KajabiSso::Configuration.enabled? && KajabiSso::Configuration.valid_credentials?

      managed_groups = KajabiSso::OfferGroupMapper.new.mapping.values.uniq
      return if managed_groups.blank?

      group_ids = Group.where(name: managed_groups).pluck(:id)
      return if group_ids.blank?

      User.real.not_suspended
        .joins(:group_users)
        .where(group_users: { group_id: group_ids })
        .distinct
        .find_each do |user|
        begin
          result = KajabiSso::ApiClient.instance.active_member?(user.email)
          KajabiSso::GroupSyncService.sync(user, result[:offer_ids])
        rescue => e
          Rails.logger.warn("[KajabiSSO] Scheduled sync failed for #{user.email}: #{e.message}")
        end
      end
    end
  end
end
