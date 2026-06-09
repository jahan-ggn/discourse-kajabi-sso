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
      return empty_membership if @email.blank?

      cached = read_cache
      return cached if cached.present?

      result = fetch_from_api
      write_cache(result)
      result
    end

    private

    def fetch_from_api
      client = ApiClient.instance
      contact = client.find_contact(@email)

      return empty_membership unless contact

      contact_id = contact.dig("id")
      customer_id = contact.dig("relationships", "customer", "data", "id")
      name = contact.dig("attributes", "name")

      offer_ids =
        if customer_id.present?
          purchase_ids = client.active_purchase_offer_ids(customer_id)
          granted_ids = client.granted_offer_ids(contact_id)
          (purchase_ids + granted_ids).uniq
        else
          []
        end

      Membership.new(contact_found: true, name: name, offer_ids: offer_ids)
    rescue UnauthorizedError => e
      Rails.logger.warn("[KajabiSSO] Authentication failed: #{e.class} | #{mask_email(@email)}")
      raise
    rescue UnavailableError => e
      Rails.logger.warn(
        "[KajabiSSO] API unavailable: #{e.class} | #{mask_email(@email)} | #{e.message}",
      )
      raise
    rescue ApiError => e
      Rails.logger.warn("[KajabiSSO] API error: #{e.class} | #{mask_email(@email)} | #{e.message}")
      empty_membership
    end

    def empty_membership
      Membership.new(contact_found: false, name: nil, offer_ids: [])
    end

    def read_cache
      cached = Rails.cache.read(cache_key)
      return cached unless cached

      Membership.new(
        contact_found: cached[:contact_found],
        name: cached[:name],
        offer_ids: cached[:offer_ids],
      )
    end

    def write_cache(membership)
      Rails.cache.write(cache_key, membership.cacheable, expires_in: MEMBERSHIP_CACHE_TTL)
    end

    def cache_key
      Infrastructure::CacheKeyBuilder.build("m", Digest::SHA256.hexdigest(@email))
    end

    def mask_email(email)
      return "blank" if email.blank?
      local, domain = email.split("@")
      return email if local.length <= 3
      "#{local[0, 3]}***@#{domain}"
    end
  end
end
