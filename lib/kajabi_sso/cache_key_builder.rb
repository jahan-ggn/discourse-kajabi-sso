# frozen_string_literal: true

module KajabiSso
  class CacheKeyBuilder
    PREFIX = "kajabi_sso"

    def self.build(*segments)
      [PREFIX, *segments].join(":")
    end
  end
end
