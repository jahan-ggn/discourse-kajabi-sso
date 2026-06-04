# frozen_string_literal: true

module ::KajabiSso
  class ApiError < StandardError
  end

  class UnauthorizedError < ApiError
  end

  class UnavailableError < ApiError
  end
end
