# frozen_string_literal: true

require "net/http"
require "json"
require "uri"
require "openssl"
require "cgi"

module ::KajabiSso
  class ApiClient
    KAJABI_AUTH_URL = "https://api.kajabi.com/v1/oauth/token"
    KAJABI_API_URL = "https://api.kajabi.com/v1"
    API_TIMEOUT = 10.seconds
    MAX_PAGES = 10

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
      return no_contact_result if email.blank?

      token = fetch_access_token
      contact = find_contact(token, email)
      return no_contact_result unless contact

      contact_id = contact.dig("id")
      customer_id = contact.dig("relationships", "customer", "data", "id")
      name = contact.dig("attributes", "name")

      offer_ids = customer_id.present? ? active_offer_ids(token, contact_id, customer_id) : []

      { contact_found: true, name: name, offer_ids: offer_ids }
    rescue UnauthorizedError, UnavailableError, ApiError => e
      Rails.logger.warn("[KajabiSSO] API error: #{e.class} | #{mask_email(email)} | #{e.message}")
      no_contact_result
    end

    def active_offer_ids(token, contact_id, customer_id)
      purchase_ids = fetch_purchase_offer_ids(token, customer_id)
      granted_ids = fetch_granted_offer_ids(token, contact_id)
      (purchase_ids + granted_ids).uniq
    end

    private

    def no_contact_result
      { contact_found: false, name: nil, offer_ids: [] }
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

      data = request_json(uri, req)
      token = data["access_token"]
      raise UnauthorizedError, "Bad credentials: #{data.inspect}" unless token

      ttl = data["expires_in"].to_i
      ttl = 3600 if ttl <= 0
      Rails.cache.write(token_cache_key, token, expires_in: ttl - 60)

      token
    end

    def find_contact(token, email)
      normalized_email = Email.downcase(email)
      encoded_email = CGI.escape(normalized_email)
      uri = URI("#{KAJABI_API_URL}/contacts?filter[search]=#{encoded_email}")

      data = authorized_json_request(uri, token)
      contacts = data["data"] || []
      return nil if contacts.empty?

      contacts.find { |c| c.dig("attributes", "email")&.downcase == normalized_email }
    end

    def fetch_purchase_offer_ids(token, customer_id)
      ids = []
      url =
        "#{KAJABI_API_URL}/purchases?filter[customer_id]=#{customer_id}&filter[active]=true&page[size]=100"
      pages_fetched = 0

      while url.present? && pages_fetched < MAX_PAGES
        data = authorized_json_request(URI(url), token)
        (data["data"] || []).each do |p|
          offer_id = p.dig("relationships", "offer", "data", "id")
          ids << offer_id if offer_id.present?
        end
        url = data.dig("links", "next")
        pages_fetched += 1
      end

      ids
    end

    def fetch_granted_offer_ids(token, contact_id)
      uri = URI("#{KAJABI_API_URL}/contacts/#{contact_id}/relationships/offers")
      data = authorized_json_request(uri, token)
      (data["data"] || []).filter_map { |o| o.dig("id") }
    rescue ApiError => e
      Rails.logger.warn("[KajabiSSO] Granted offers fetch failed: #{e.message}")
      []
    end

    def authorized_json_request(uri, token)
      req = Net::HTTP::Get.new(uri)
      req["Authorization"] = "Bearer #{token}"
      req["Accept"] = "application/json"
      request_json(uri, req)
    end

    def request_json(uri, request)
      res = perform_request(uri, request)
      parse_json(res)
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
