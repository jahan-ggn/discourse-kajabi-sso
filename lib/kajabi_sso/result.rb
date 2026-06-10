# frozen_string_literal: true

module KajabiSso
  class Result
    attr_reader :error, :user, :value

    def initialize(success:, error: nil, user: nil, value: nil)
      @success = !!success
      @error = error
      @user = user
      @value = value
    end

    def self.success(value: nil, user: nil)
      new(success: true, value: value, user: user)
    end

    def self.failure(error)
      new(success: false, error: error)
    end

    def success?
      @success
    end

    def failure?
      !@success
    end

    def to_h
      { success: @success, error: @error }.compact
    end
  end
end
