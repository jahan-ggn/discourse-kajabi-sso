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

      groups_by_name = Group.where(name: to_add + to_remove).index_by(&:name)
      actual_add = to_add.filter { |name| groups_by_name.key?(name) }
      actual_remove = to_remove.filter { |name| groups_by_name.key?(name) }

      return if actual_add.empty? && actual_remove.empty?

      Group.transaction do
        actual_add.each { |name| add_to_group(groups_by_name[name]) }
        actual_remove.each { |name| remove_from_group(groups_by_name[name]) }
      end

      log_sync(actual_add, actual_remove)

      MessageBus.publish(
        "/user/#{@user.id}",
        { type: "refresh_groups", groups: @user.groups.map { |g| { id: g.id, name: g.name } } },
        user_ids: [@user.id],
      )
    end

    def add_only
      return if @user.blank? || @user.staged?

      target_names = Mappings.group_names_for(@offer_ids)
      current_names = @user.groups.where(name: target_names).pluck(:name)

      to_add = target_names - current_names
      return if to_add.empty?

      groups_by_name = Group.where(name: to_add).index_by(&:name)
      actual_add = to_add.filter { |name| groups_by_name.key?(name) }

      return if actual_add.empty?

      actual_add.each { |name| add_to_group(groups_by_name[name]) }

      Rails.logger.info("[KajabiSSO] GroupAdd user=#{@user.id} +[#{actual_add.join(",")}]")

      MessageBus.publish(
        "/user/#{@user.id}",
        { type: "refresh_groups", groups: @user.groups.map { |g| { id: g.id, name: g.name } } },
        user_ids: [@user.id],
      )
    end

    private

    def add_to_group(group)
      return unless group

      group.add(@user)
    end

    def remove_from_group(group)
      return unless group

      group.remove(@user)
    end

    def log_sync(added, removed)
      Rails.logger.info(
        "[KajabiSSO] GroupSync user=#{@user.id} +[#{added.join(",")}] -[#{removed.join(",")}]",
      )
    end
  end
end
