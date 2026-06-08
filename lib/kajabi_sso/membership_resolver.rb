# frozen_string_literal: true

module KajabiSso
  class MembershipResolver
    MEMBERSHIP_CACHE_TTL = 30.seconds

    def self.resolve(email)
      new(email).resolve
    end

    def initialize(email)
      @email = email
    end

    def resolve
      return no_contact_result if @email.blank?

      cached = read_cache
      return cached if cached.present?

      result = fetch_from_api
      write_cache(result)
      result
    end

    private

    def fetch_from_api
      client = ApiClient.instance
      token = client.fetch_access_token
      contact = client.find_contact(token, @email)

      return no_contact_result unless contact

      contact_id = contact.dig("id")
      customer_id = contact.dig("relationships", "customer", "data", "id")
      name = contact.dig("attributes", "name")

      offer_ids =
        if customer_id.present?
          purchase_ids = client.active_purchase_offer_ids(token, customer_id)
          granted_ids = client.granted_offer_ids(token, contact_id)
          (purchase_ids + granted_ids).uniq
        else
          []
        end

      { contact_found: true, name: name, offer_ids: offer_ids }
    rescue UnauthorizedError, UnavailableError, ApiError => e
      Rails.logger.warn(
        "[KajabiSSO] API error: #{e.class} | #{mask_email(@email)} | #{e.message}"
      )
      no_contact_result
    end

    def no_contact_result
      { contact_found: false, name: nil, offer_ids: [] }
    end

    def read_cache
      Rails.cache.read(cache_key)
    end

    def write_cache(result)
      Rails.cache.write(
        cache_key,
        {
          contact_found: result[:contact_found],
          name: result[:name],
          offer_ids: result[:offer_ids]
        },
        expires_in: MEMBERSHIP_CACHE_TTL
      )
    end

    def cache_key
      db =
        begin
          RailsMultisite::ConnectionManagement.current_db
        rescue StandardError
          "default"
        end
      "#{db}:kajabi_sso:m:#{Digest::SHA256.hexdigest(@email)}"
    end

    def mask_email(email)
      return "blank" if email.blank?
      local, domain = email.split("@")
      return email if local.length <= 3
      "#{local[0, 3]}***@#{domain}"
    end
  end
end
