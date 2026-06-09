# frozen_string_literal: true

module KajabiSso
  class KajabiSsoError < StandardError
  end

  class ApiError < KajabiSsoError
  end
  class UnauthorizedError < ApiError
  end
  class UnavailableError < ApiError
  end
  class CircuitOpenError < UnavailableError
  end
end
