# frozen_string_literal: true

module KajabiSso
  class GroupMembershipChangeset
    attr_reader :user, :to_add, :to_remove

    def initialize(user:, to_add:, to_remove:)
      @user = user
      @to_add = Array(to_add)
      @to_remove = Array(to_remove)
    end

    def empty?
      @to_add.empty? && @to_remove.empty?
    end
  end
end
