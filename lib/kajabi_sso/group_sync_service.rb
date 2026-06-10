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

      apply_changes(to_add: to_add, to_remove: to_remove)
    end

    def add_only
      return if @user.blank? || @user.staged?

      target_names = Mappings.group_names_for(@offer_ids)
      current_names = @user.groups.where(name: target_names).pluck(:name)

      to_add = target_names - current_names

      apply_changes(to_add: to_add, to_remove: [])
    end

    private

    def apply_changes(to_add:, to_remove:)
      groups_by_name = Group.where(name: to_add + to_remove).index_by(&:name)

      actual_add = to_add.filter { |name| groups_by_name.key?(name) }
      actual_remove = to_remove.filter { |name| groups_by_name.key?(name) }

      return if actual_add.empty? && actual_remove.empty?

      Group.transaction do
        actual_add.each { |name| groups_by_name[name].add(@user) }
        actual_remove.each { |name| groups_by_name[name].remove(@user) }
      end

      log_changes(actual_add, actual_remove)
      publish_refresh
    end

    def log_changes(added, removed)
      Rails.logger.info(
        "[KajabiSSO] GroupSync user=#{@user.id} +[#{added.join(",")}] -[#{removed.join(",")}]",
      )
    end

    def publish_refresh
      MessageBus.publish(
        "/user/#{@user.id}",
        { type: "refresh_groups", groups: @user.groups.map { |g| { id: g.id, name: g.name } } },
        user_ids: [@user.id],
      )
    end
  end
end
