# frozen_string_literal: true

module KajabiSso
  module Infrastructure
    class CacheKeyBuilder
      PREFIX = "kajabi_sso"

      def self.build(*segments)
        [PREFIX, *segments].join(":")
      end
    end
  end
end
