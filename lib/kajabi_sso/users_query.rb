# frozen_string_literal: true

module KajabiSso
  class UsersQuery
    def self.to_sync(group_ids)
      new(group_ids).to_sync
    end

    def initialize(group_ids)
      @group_ids = group_ids
    end

    def to_sync
      return User.none if @group_ids.blank?

      user_ids = fetch_user_ids
      return User.none if user_ids.empty?

      User.real.not_suspended.where(id: user_ids)
    end

    private

    def fetch_user_ids
      group_user_ids = GroupUser.where(group_id: @group_ids).distinct.pluck(:user_id)
      custom_field_user_ids = UserCustomField.where(name: "kajabi_sso").distinct.pluck(:user_id)

      (group_user_ids + custom_field_user_ids).uniq
    end
  end
end
