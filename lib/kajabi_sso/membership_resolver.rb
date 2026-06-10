# frozen_string_literal: true

module KajabiSso
  class MembershipResolver
    MEMBERSHIP_CACHE_TTL = 30.seconds

    def initialize(api_client:, cache: Rails.cache, logger: Rails.logger)
      @api_client = api_client
      @cache = cache
      @logger = logger
    end

    def self.resolve(email)
      new(
        api_client:
          ApiClient.new(
            authenticator:
              ApiAuthenticator.new(
                client_id: SiteSetting.kajabi_client_id,
                client_secret: SiteSetting.kajabi_client_secret,
                base_uri: ApiClient::BASE_URI,
              ),
          ),
      ).resolve(email)
    end

    def resolve(email)
      return empty_membership if email.blank?

      cached = read_cache(email)
      return cached if cached.present?

      result = fetch_from_api(email)
      write_cache(email, result)
      result
    end

    private

    def fetch_from_api(email)
      contact = @api_client.find_contact(email)
      return empty_membership unless contact

      contact_id = contact.dig("id")
      customer_id = contact.dig("relationships", "customer", "data", "id")
      name = contact.dig("attributes", "name")

      offer_ids =
        if customer_id.present?
          purchase_ids = @api_client.active_purchase_offer_ids(customer_id)
          granted_ids = @api_client.granted_offer_ids(contact_id)
          (purchase_ids + granted_ids).uniq
        else
          []
        end

      Membership.new(contact_found: true, name: name, offer_ids: offer_ids)
    rescue UnauthorizedError => e
      @logger.warn("[KajabiSSO] Authentication failed: #{e.class} | #{mask_email(email)}")
      raise
    rescue UnavailableError => e
      @logger.warn("[KajabiSSO] API unavailable: #{e.class} | #{mask_email(email)} | #{e.message}")
      raise
    rescue ApiError => e
      @logger.warn("[KajabiSSO] API error: #{e.class} | #{mask_email(email)} | #{e.message}")
      empty_membership
    end

    def empty_membership
      Membership.new(contact_found: false, name: nil, offer_ids: [])
    end

    def read_cache(email)
      cached = @cache.read(cache_key(email))
      return nil unless cached

      Membership.new(
        contact_found: cached[:contact_found],
        name: cached[:name],
        offer_ids: cached[:offer_ids],
      )
    end

    def write_cache(email, membership)
      @cache.write(cache_key(email), membership.cacheable, expires_in: MEMBERSHIP_CACHE_TTL)
    end

    def cache_key(email)
      CacheKeyBuilder.build("m", Digest::SHA256.hexdigest(email))
    end

    def mask_email(email)
      return "blank" if email.blank?
      local, domain = email.split("@")
      return email if local.length <= 3
      "#{local[0, 3]}***@#{domain}"
    end
  end
end
