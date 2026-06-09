# frozen_string_literal: true

module KajabiSso
  class GroupSyncService
    def self.sync(user, offer_ids)
      new(user, offer_ids).sync
    end

    def self.add_for_offer(user, offer_id)
      new(user, [offer_id]).add_only
    end

    def initialize(user, offer_ids)
      @user = user
      @offer_ids = Array(offer_ids).map(&:to_s)
    end

    def sync
      return if @user.blank? || @user.staged?

      target_names = Mappings.group_names_for(@offer_ids)
      managed_names = Mappings.managed_group_names
      current_names = @user.groups.where(name: managed_names).pluck(:name)

      to_add = target_names - current_names
      to_remove = current_names - target_names

      apply_changeset(to_add: to_add, to_remove: to_remove)
    end

    def add_only
      return if @user.blank? || @user.staged?

      target_names = Mappings.group_names_for(@offer_ids)
      current_names = @user.groups.where(name: target_names).pluck(:name)

      to_add = target_names - current_names

      apply_changeset(to_add: to_add, to_remove: [])
    end

    private

    def apply_changeset(to_add:, to_remove:)
      changeset = GroupMembershipChangeset.new(user: @user, to_add: to_add, to_remove: to_remove)

      GroupMembershipUpdater.apply(changeset)
    end
  end
end
