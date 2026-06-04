# frozen_string_literal: true

module KajabiSso
  class Result
    attr_reader :error, :user

    def initialize(success:, error: nil, user: nil)
      @success = !!success
      @error = error
      @user = user
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
