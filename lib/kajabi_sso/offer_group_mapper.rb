# frozen_string_literal: true

module KajabiSso
  class OfferGroupMapper
    def self.mapping
      new.mapping
    end

    def mapping
      parse(SiteSetting.kajabi_offer_group_mapping)
    end

    def groups_for(offer_ids)
      return [] if offer_ids.blank?

      offer_ids = Array(offer_ids).map(&:to_s)
      m = mapping
      offer_ids.filter_map { |id| m[id] }.uniq
    end

    private

    def parse(raw)
      result = {}
      return result if raw.blank?

      raw.split("|").each do |entry|
        entry = entry.strip
        next if entry.blank?

        offer_id, group_name = entry.split(":", 2)
        next if offer_id.blank? || group_name.blank?

        result[offer_id.strip] = group_name.strip
      end
      result
    end
  end
end
