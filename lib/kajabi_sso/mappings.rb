# frozen_string_literal: true

module KajabiSso
  class Mappings
    CACHE_KEY = "kajabi_sso:mappings"
    CACHE_TTL = 5.minutes

    class << self
      def mapping
        Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) { parse }
      end

      def clear_cache!
        Rails.cache.delete(cache_key)
      end

      def group_ids_for(offer_ids)
        return [] if offer_ids.blank?

        mappings = mapping
        Array(offer_ids).filter_map { |id| mappings[id.to_s]&.id }
      end

      def group_names_for(offer_ids)
        return [] if offer_ids.blank?

        mappings = mapping
        Array(offer_ids).filter_map { |id| mappings[id.to_s]&.name }
      end

      def managed_group_ids
        mapping.values.map(&:id).uniq
      end

      def managed_group_names
        mapping.values.map(&:name).uniq
      end

      private

      def parse
        raw = SiteSetting.kajabi_offer_group_mapping.to_s.strip
        return {} if raw.blank?

        entries = []
        raw
          .split("|")
          .each do |entry|
            entry = entry.strip
            next if entry.blank? || entry.start_with?("#")

            offer_id, group_name = entry.split(":", 2).map(&:strip)
            next if offer_id.blank? || group_name.blank?

            entries << [offer_id, group_name]
          end

        group_names = entries.map(&:last).uniq
        groups_by_name = Group.where(name: group_names).index_by(&:name)

        mappings = {}
        entries.each do |offer_id, group_name|
          group = groups_by_name[group_name]
          unless group
            Rails.logger.warn("[KajabiSSO] Mapped group '#{group_name}' not found; skipping.")
            next
          end

          mappings[offer_id] = group
        end

        mappings
      end

      def cache_key
        db =
          begin
            RailsMultisite::ConnectionManagement.current_db
          rescue StandardError
            "default"
          end
        "#{db}:#{CACHE_KEY}"
      end
    end
  end
end
