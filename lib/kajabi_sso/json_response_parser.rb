# frozen_string_literal: true

require "json"

module KajabiSso
  class JsonResponseParser
    def self.parse(response)
      raise UnauthorizedError, "Invalid client credentials" if response.code == "401"
      raise ApiError, "HTTP #{response.code}" unless response.is_a?(Net::HTTPSuccess)
      JSON.parse(response.body)
    rescue JSON::ParserError
      raise ApiError, "Invalid JSON from Kajabi"
    end
  end
end
