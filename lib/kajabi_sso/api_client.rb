# frozen_string_literal: true

require "cgi"

module KajabiSso
  class ApiClient
    BASE_URI = "https://api.kajabi.com/v1/"

    def initialize(authenticator:, transport:)
      @authenticator = authenticator
      @transport = transport
    end

    def self.instance
      transport = Infrastructure::HttpTransport.new
      new(
        authenticator:
          Infrastructure::KajabiAuthenticator.new(
            client_id: SiteSetting.kajabi_client_id,
            client_secret: SiteSetting.kajabi_client_secret,
            base_uri: BASE_URI,
            transport: transport,
            cache: Rails.cache,
          ),
        transport: transport,
      )
    end

    def find_contact(email)
      CircuitBreaker.check
      token = @authenticator.access_token
      normalized_email = Email.downcase(email)
      encoded_email = CGI.escape(normalized_email)
      uri = build_uri("/contacts?filter[search]=#{encoded_email}")

      req = Net::HTTP::Get.new(uri)
      data = authorized_json_request(uri, req, token)

      contacts = data["data"] || []
      return nil if contacts.empty?

      contact = contacts.find { |c| c.dig("attributes", "email")&.downcase == normalized_email }
      CircuitBreaker.record_success if contact
      contact
    rescue UnavailableError, CircuitOpenError => e
      CircuitBreaker.record_failure
      raise e
    end

    def active_purchase_offer_ids(customer_id)
      token = @authenticator.access_token
      base_path = "/purchases?filter[customer_id]=#{customer_id}&filter[active]=true&page[size]=100"

      Infrastructure::PaginatedCollection
        .new(initial_url: build_uri(base_path), fetch_page: ->(url) { fetch_page(url, token) })
        .filter_map { |p| p.dig("relationships", "offer", "data", "id") }
        .uniq
    end

    def granted_offer_ids(contact_id)
      token = @authenticator.access_token
      uri = build_uri("/contacts/#{contact_id}/relationships/offers")
      req = Net::HTTP::Get.new(uri)
      data = authorized_json_request(uri, req, token)
      (data["data"] || []).filter_map { |o| o.dig("id") }
    rescue ApiError => e
      Rails.logger.warn("[KajabiSSO] Granted offers fetch failed: #{e.message}")
      []
    end

    def offers
      token = @authenticator.access_token
      base_path = "/offers?page[size]=100"

      Infrastructure::PaginatedCollection
        .new(initial_url: build_uri(base_path), fetch_page: ->(url) { fetch_page(url, token) })
        .map do |o|
          {
            id: o.dig("id"),
            title: o.dig("attributes", "title"),
            internal_title: o.dig("attributes", "internal_title"),
          }
        end
    end

    private

    def build_uri(path)
      URI("#{BASE_URI}#{path.delete_prefix("/")}")
    end

    def authorized_json_request(uri, req, token)
      req["Authorization"] = "Bearer #{token}"
      req["Accept"] = "application/json"
      request_json(uri, req)
    end

    def request_json(uri, req)
      response = @transport.request(uri, req)
      KajabiSso::Infrastructure::JsonResponseParser.parse(response)
    end

    def fetch_page(url, token)
      uri = url.is_a?(URI) ? url : URI(url)
      req = Net::HTTP::Get.new(uri)
      req["Authorization"] = "Bearer #{token}"
      req["Accept"] = "application/json"
      response = @transport.request(uri, req)
      KajabiSso::Infrastructure::JsonResponseParser.parse(response)
    end
  end
end
