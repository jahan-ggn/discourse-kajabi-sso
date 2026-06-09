# frozen_string_literal: true

module KajabiSso
  class Membership
    attr_reader :contact_found, :name, :offer_ids

    def initialize(contact_found:, name:, offer_ids:)
      @contact_found = contact_found
      @name = name
      @offer_ids = Array(offer_ids)
    end

    def found?
      @contact_found
    end

    def cacheable
      {
        contact_found: @contact_found,
        name: @name,
        offer_ids: @offer_ids,
      }
    end
  end
end
