# frozen_string_literal: true

module NeedhamCircle
  module Sync
    class LetsBike
      Sync.register(self)

      BASE_URL = "https://www.letsbikeneedham.com"
      ENDPOINT = "#{BASE_URL}/events?format=json"
      TIMEZONE = "America/New_York"

      def initialize(endpoint: ENDPOINT, logger: nil)
        @endpoint = endpoint
        @logger = logger
      end

      def source
        Source::LBN
      end

      def fetch_events
        payload = Sync::HTTP.get_json(@endpoint, logger: @logger)
        return nil if payload.nil?

        (payload["upcoming"] || []).map do |raw|
          Event.new(
            source_id: raw.fetch("id"),
            title: raw.fetch("title"),
            description: Sync.html_to_text(raw.fetch("body")),
            location: format_location(raw.fetch("location")),
            url: File.join(BASE_URL, raw.fetch("fullUrl")),
            start_at: format_timestamp(raw.fetch("startDate")),
            end_at: format_timestamp(raw.fetch("endDate")),
            timezone: TIMEZONE
          )
        end
      end

      private

      def format_location(location)
        location
          .values_at("addressTitle", "addressLine1", "addressLine2", "addressCountry")
          .select { |part| !part.empty? }
          .then { |result| result.join(", ") if result.any? }
      end

      def format_timestamp(ms)
        Time.at(ms / 1000.0).utc.strftime("%Y-%m-%dT%H:%M:%SZ")
      end
    end
  end
end
