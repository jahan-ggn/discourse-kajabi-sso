# frozen_string_literal: true

require "net/http"
require "openssl"

module KajabiSso
  module Infrastructure
    class HttpTransport
      DEFAULT_TIMEOUT = 10.seconds
      OPEN_TIMEOUT = 5

      def initialize(timeout: DEFAULT_TIMEOUT, ssl_verify: true)
        @timeout = timeout
        @ssl_verify = ssl_verify
      end

      def request(uri, http_request)
        http = build_http(uri)
        http.request(http_request)
      rescue Net::OpenTimeout
        raise UnavailableError, "Kajabi connection timed out"
      rescue Net::ReadTimeout
        raise UnavailableError, "Kajabi read timed out"
      rescue OpenSSL::SSL::SSLError
        raise UnavailableError, "Kajabi SSL error"
      rescue SocketError, Errno::ECONNREFUSED, Errno::ETIMEDOUT => e
        raise UnavailableError, "Kajabi is unreachable (#{e.class})"
      end

      private

      def build_http(uri)
        http = FinalDestination::HTTP.new(uri.hostname, uri.port)
        http.use_ssl = (uri.scheme == "https")
        http.open_timeout = OPEN_TIMEOUT
        http.read_timeout = @timeout
        http.verify_mode = @ssl_verify ? OpenSSL::SSL::VERIFY_PEER : OpenSSL::SSL::VERIFY_NONE
        http
      end
    end
  end
end
