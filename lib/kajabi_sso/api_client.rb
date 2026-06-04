# frozen_string_literal: true

require "net/http"
require "json"
require "uri"
require "openssl"
require "cgi"
require_relative "errors"

module ::KajabiSso
  class ApiClient
    KAJABI_AUTH_URL = "https://api.kajabi.com/v1/oauth/token"
    KAJABI_API_URL = "https://api.kajabi.com/v1"
    API_TIMEOUT = 10.seconds

    class << self
      def instance
        new(SiteSetting.kajabi_client_id, SiteSetting.kajabi_client_secret)
      end
    end

    def initialize(client_id, client_secret)
      @client_id = client_id
      @client_secret = client_secret
    end

    def active_member?(email)
      return inactive_result if email.blank?

      token = fetch_access_token
      contact = find_contact(token, email)
      return inactive_result unless contact

      customer_id = contact.dig("relationships", "customer", "data", "id")
      paid = customer_id.present? && has_active_purchase?(token, customer_id)
      name = contact.dig("attributes", "name")

      { active: true, name: name, paid: paid }
    rescue UnauthorizedError, UnavailableError, ApiError => e
      Rails.logger.warn("[KajabiSSO] API error: #{e.class} | #{mask_email(email)} | #{e.message}")
      inactive_result
    end

    private

    def inactive_result
      { active: false, name: nil, paid: false }
    end

    def fetch_access_token
      cached = Rails.cache.read(token_cache_key)
      return cached if cached.present?

      uri = URI(KAJABI_AUTH_URL)
      req = Net::HTTP::Post.new(uri)
      req.set_form_data(
        grant_type: "client_credentials",
        client_id: @client_id,
        client_secret: @client_secret,
      )

      res = perform_request(uri, req)
      data = parse_json(res)

      raise UnauthorizedError, "Bad credentials: #{data.inspect}" unless data["access_token"]

      ttl = data["expires_in"].to_i
      ttl = 3600 if ttl <= 0
      Rails.cache.write(token_cache_key, data["access_token"], expires_in: ttl - 60)

      data["access_token"]
    end

    def find_contact(token, email)
      normalized_email = Email.downcase(email)
      encoded_email = CGI.escape(normalized_email)
      uri = URI("#{KAJABI_API_URL}/contacts?filter[search]=#{encoded_email}")

      req = Net::HTTP::Get.new(uri)
      req["Authorization"] = "Bearer #{token}"
      req["Accept"] = "application/json"

      res = perform_request(uri, req)
      data = parse_json(res)

      contacts = data["data"] || []
      return nil if contacts.empty?

      contacts.find { |c| c.dig("attributes", "email")&.downcase == normalized_email }
    end

    def has_active_purchase?(token, customer_id)
      url = "#{KAJABI_API_URL}/purchases?filter[customer_id]=#{customer_id}&page[size]=100"
      pages_fetched = 0
      max_pages = 10

      while url.present? && pages_fetched < max_pages
        uri = URI(url)
        req = Net::HTTP::Get.new(uri)
        req["Authorization"] = "Bearer #{token}"
        req["Accept"] = "application/json"

        res = perform_request(uri, req)
        data = parse_json(res)

        purchases = data["data"] || []
        return true if purchases.any? { |p| p.dig("attributes", "deactivated_at").nil? }

        url = data.dig("links", "next")
        pages_fetched += 1
      end

      if pages_fetched >= max_pages && url.present?
        Rails.logger.warn(
          "[KajabiSSO] Purchase pagination hit max_pages for customer #{customer_id}",
        )
      end

      false
    end

    def perform_request(uri, request)
      http = FinalDestination::HTTP.new(uri.hostname, uri.port)
      http.use_ssl = (uri.scheme == "https")
      http.open_timeout = 5
      http.read_timeout = API_TIMEOUT
      http.verify_mode = OpenSSL::SSL::VERIFY_PEER

      http.request(request)
    rescue Net::OpenTimeout
      raise UnavailableError, "Kajabi connection timed out"
    rescue Net::ReadTimeout
      raise UnavailableError, "Kajabi read timed out"
    rescue SocketError, Errno::ECONNREFUSED, Errno::ETIMEDOUT => e
      raise UnavailableError, "Kajabi is unreachable (#{e.class})"
    end

    def parse_json(response)
      unless response.is_a?(Net::HTTPSuccess)
        msg = "HTTP #{response.code}"
        msg += ": #{response.body&.first(200)}" if Rails.env.development?
        raise ApiError, msg
      end

      JSON.parse(response.body)
    rescue JSON::ParserError
      raise ApiError, "Invalid JSON from Kajabi"
    end

    def mask_email(email)
      return "blank" if email.blank?
      local, domain = email.split("@")
      return email if local.length <= 3
      "#{local[0, 3]}***@#{domain}"
    end

    def token_cache_key
      db =
        begin
          RailsMultisite::ConnectionManagement.current_db
        rescue StandardError
          "default"
        end
      "#{db}:kajabi_sso:token"
    end
  end
end
