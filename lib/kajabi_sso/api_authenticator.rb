# frozen_string_literal: true

require "net/http"
require "uri"

module KajabiSso
  class ApiAuthenticator
    TOKEN_PATH = "oauth/token"
    TOKEN_CACHE_BUFFER = 60

    def initialize(client_id:, client_secret:, base_uri:, transport: HttpTransport.new, cache: Rails.cache)
      @client_id = client_id
      @client_secret = client_secret
      @base_uri = base_uri.to_s
      @transport = transport
      @cache = cache
    end

    def access_token
      cached = @cache.read(cache_key)
      return cached if cached.present?

      token_data = fetch_token
      @cache.write(
        cache_key,
        token_data[:token],
        expires_in: token_data[:expires_in] - TOKEN_CACHE_BUFFER,
      )
      token_data[:token]
    end

    private

    def fetch_token
      uri = URI("#{@base_uri}#{TOKEN_PATH}")

      req = Net::HTTP::Post.new(uri)
      req.set_form_data(
        grant_type: "client_credentials",
        client_id: @client_id,
        client_secret: @client_secret,
      )

      response = @transport.request(uri, req)
      data = JsonResponseParser.parse(response)

      token = data["access_token"]
      raise UnauthorizedError, "Bad credentials: #{data.inspect}" unless token

      ttl = data["expires_in"].to_i
      ttl = 3600 if ttl <= 0

      { token: token, expires_in: ttl }
    end

    def cache_key
      CacheKeyBuilder.build("token", Digest::SHA256.hexdigest(@client_id))
    end
  end
end
