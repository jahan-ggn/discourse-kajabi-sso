# frozen_string_literal: true

module KajabiSso
  class GroupMembershipUpdater
    def self.apply(changeset)
      new(changeset).apply
    end

    def initialize(changeset)
      @changeset = changeset
    end

    def apply
      return if @changeset.empty?

      groups_by_name = Group.where(name: @changeset.to_add + @changeset.to_remove).index_by(&:name)

      actual_add = @changeset.to_add.filter { |name| groups_by_name.key?(name) }
      actual_remove = @changeset.to_remove.filter { |name| groups_by_name.key?(name) }

      return if actual_add.empty? && actual_remove.empty?

      Group.transaction do
        actual_add.each { |name| groups_by_name[name].add(@changeset.user) }
        actual_remove.each { |name| groups_by_name[name].remove(@changeset.user) }
      end

      log_changes(actual_add, actual_remove)
      publish_refresh
    end

    private

    def log_changes(added, removed)
      Rails.logger.info(
        "[KajabiSSO] GroupSync user=#{@changeset.user.id} +[#{added.join(",")}] -[#{removed.join(",")}]"
      )
    end

    def publish_refresh
      MessageBus.publish(
        "/user/#{@changeset.user.id}",
        {
          type: "refresh_groups",
          groups: @changeset.user.groups.map { |g| { id: g.id, name: g.name } }
        },
        user_ids: [@changeset.user.id]
      )
    end
  end
end
