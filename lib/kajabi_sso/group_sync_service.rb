# frozen_string_literal: true

module KajabiSso
  class GroupSyncService
    def self.sync(user, offer_ids)
      new(user, offer_ids).sync
    end

    def initialize(user, offer_ids)
      @user = user
      @offer_ids = offer_ids
    end

    def sync
      return if @user.blank? || @user.staged?

      target_groups = mapper.groups_for(@offer_ids)
      managed = managed_group_names
      current = current_managed_groups(managed)

      to_add = target_groups - current
      to_remove = current - target_groups

      to_add.each { |name| add_to_group(name) }
      to_remove.each { |name| remove_from_group(name) }

      log_sync(to_add, to_remove)
    end

    private

    def mapper
      @mapper ||= KajabiSso::OfferGroupMapper.new
    end

    def managed_group_names
      mapper.mapping.values.uniq
    end

    def current_managed_groups(managed)
      @user.groups.where(name: managed).pluck(:name)
    end

    def add_to_group(name)
      group = Group.find_by_name(name)
      return unless group

      group.add(@user)
    end

    def remove_from_group(name)
      group = Group.find_by_name(name)
      return unless group

      group.remove(@user)
    end

    def log_sync(added, removed)
      if added.any? || removed.any?
      end
    end
  end
end
