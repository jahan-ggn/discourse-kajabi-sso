# frozen_string_literal: true

module KajabiSso
  module Infrastructure
    class PaginatedCollection
      include Enumerable

      MAX_PAGES = 10

      def initialize(initial_url:, fetch_page:, max_pages: MAX_PAGES)
        @initial_url = initial_url
        @fetch_page = fetch_page
        @max_pages = max_pages
      end

      def each
        return to_enum unless block_given?

        url = @initial_url
        pages = 0

        loop do
          data = @fetch_page.call(url)
          items = data["data"] || []
          items.each { |item| yield item }

          url = data.dig("links", "next")
          pages += 1
          break if url.blank? || pages >= @max_pages
        end
      end
    end
  end
end
