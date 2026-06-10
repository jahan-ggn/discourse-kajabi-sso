# frozen_string_literal: true

require "cgi"

module KajabiSso
  class ApiClient
    BASE_URI = "https://api.kajabi.com/v1/"

    def initialize(authenticator:, transport: HttpTransport.new, logger: Rails.logger)
      @authenticator = authenticator
      @transport = transport
      @logger = logger
    end

    def find_contact(email)
      token = @authenticator.access_token
      normalized_email = email.to_s.strip.downcase
      encoded_email = CGI.escape(normalized_email)
      uri = build_uri("/contacts?filter[search]=#{encoded_email}")

      data = get_json(uri, token)
      contacts = data["data"] || []
      return nil if contacts.empty?

      contacts.find { |c| c.dig("attributes", "email")&.downcase == normalized_email }
    end

    def active_purchase_offer_ids(customer_id)
      token = @authenticator.access_token
      base_path = "/purchases?filter[customer_id]=#{customer_id}&filter[active]=true&page[size]=100"

      PaginatedCollection
        .new(initial_url: build_uri(base_path), fetch_page: ->(url) { get_json(url, token) })
        .filter_map { |p| p.dig("relationships", "offer", "data", "id") }
        .uniq
    end

    def granted_offer_ids(contact_id)
      token = @authenticator.access_token
      uri = build_uri("/contacts/#{contact_id}/relationships/offers")

      data = get_json(uri, token)
      (data["data"] || []).filter_map { |o| o.dig("id") }
    rescue ApiError => e
      @logger.warn("[KajabiSSO] Granted offers fetch failed: #{e.message}")
      []
    end

    def offers
      token = @authenticator.access_token
      base_path = "/offers?page[size]=100"

      PaginatedCollection
        .new(initial_url: build_uri(base_path), fetch_page: ->(url) { get_json(url, token) })
        .map do |o|
          {
            id: o.dig("id"),
            title: o.dig("attributes", "title"),
            internal_title: o.dig("attributes", "internal_title"),
          }
        end
    end

    def self.clear_token_cache!
      Rails.cache.delete(/^kajabi_sso:token:/)
    end

    private

    def build_uri(path)
      URI("#{BASE_URI}#{path.delete_prefix("/")}")
    end

    def get_json(uri, token)
      uri = URI(uri) unless uri.is_a?(URI)
      req = Net::HTTP::Get.new(uri)
      req["Authorization"] = "Bearer #{token}"
      req["Accept"] = "application/json"

      response = @transport.request(uri, req)
      JsonResponseParser.parse(response)
    end
  end
end
