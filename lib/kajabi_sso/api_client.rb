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
    KAJABI_API_URL  = "https://api.kajabi.com/v1"
    TOKEN_CACHE_KEY = "kajabi_sso:token"
    API_TIMEOUT     = 10.seconds

    def initialize(client_id, client_secret)
      @client_id     = client_id
      @client_secret = client_secret
    end

    def active_member?(email)
      return { active: false, name: nil, paid: false } if email.blank?

      token = fetch_access_token

      contact = find_contact(token, email)
      return { active: false, name: nil, paid: false } unless contact

      customer_id = contact.dig("relationships", "customer", "data", "id")

      paid =
        customer_id.present? &&
        has_active_purchase?(token, customer_id)

      name = contact.dig("attributes", "name")

      {
        active: true,
        name: name,
        paid: paid
      }

    rescue ApiError => e
      Rails.logger.error("[KajabiSSO] API: #{e.class} | #{mask_email(email)} | #{e.message}")

      { active: false, name: nil, paid: false }

    rescue StandardError => e
      Rails.logger.error("[KajabiSSO] Unexpected: #{e.class} | #{mask_email(email)} | #{e.message}")

      { active: false, name: nil, paid: false }
    end

    private

    def fetch_access_token
      cached = Rails.cache.read(TOKEN_CACHE_KEY)
      return cached if cached.present?

      uri = URI(KAJABI_AUTH_URL)
      req = Net::HTTP::Post.new(uri)
      req.set_form_data(
        grant_type:    "client_credentials",
        client_id:     @client_id,
        client_secret: @client_secret
      )

      res  = perform_request(uri, req)
      data = parse_json(res)

      raise UnauthorizedError, "Bad credentials: #{data.inspect}" unless data["access_token"]

      ttl = data["expires_in"].to_i
      ttl = 3600 if ttl <= 0
      Rails.cache.write(TOKEN_CACHE_KEY, data["access_token"], expires_in: ttl - 60)

      data["access_token"]
    end

    def find_contact(token, email)
      normalized_email = email.downcase.strip
      encoded_email    = CGI.escape(normalized_email)
      uri = URI("#{KAJABI_API_URL}/contacts?filter[search]=#{encoded_email}")

      req = Net::HTTP::Get.new(uri)
      req["Authorization"] = "Bearer #{token}"
      req["Accept"]         = "application/json"

      res  = perform_request(uri, req)
      data = parse_json(res)

      contacts = data["data"] || []
      return nil if contacts.empty?

      contact = contacts.find do |c|
        c.dig("attributes", "email")&.downcase == normalized_email
      end
      raise ContactNotFound if contact.nil?

      contact
    end

    def has_active_purchase?(token, customer_id)
      uri = URI("#{KAJABI_API_URL}/purchases?filter[customer_id]=#{customer_id}&page[size]=100")

      req = Net::HTTP::Get.new(uri)
      req["Authorization"] = "Bearer #{token}"
      req["Accept"]         = "application/json"

      res  = perform_request(uri, req)
      data = parse_json(res)

      purchases = data["data"] || []
      return false if purchases.empty?

      purchases.any? do |purchase|
        purchase.dig("attributes", "deactivated_at").nil?
      end
    end

    def perform_request(uri, request)
      http = FinalDestination::HTTP.new(uri.hostname, uri.port)
      http.use_ssl      = (uri.scheme == "https")
      http.open_timeout  = 5
      http.read_timeout  = API_TIMEOUT
      http.verify_mode   = OpenSSL::SSL::VERIFY_PEER

      http.request(request)
    rescue Net::OpenTimeout, Net::ReadTimeout
      raise UnavailableError, "Kajabi timed out"
    rescue SocketError, Errno::ECONNREFUSED
      raise UnavailableError, "Kajabi is unreachable"
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
  end
end
