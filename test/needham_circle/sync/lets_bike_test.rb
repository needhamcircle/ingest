# frozen_string_literal: true

require "test_helper"

module NeedhamCircle
  module Sync
    class LetsBikeTest < Test
      def setup
        @calendar = FakeCalendar.new
      end

      def test_inserts_when_no_existing_events
        assert_sync(
          "upcoming" => [
            event_payload("id" => "a"),
            event_payload("id" => "b", "title" => "Group Ride")
          ]
        )

        assert_equal 2, @calendar.upserts.size
        assert_nil @calendar.upserts[0][0]
        assert_equal "a", @calendar.upserts[0][1].source_id
        assert_equal "Group Ride", @calendar.upserts[1][1].title
      end

      def test_updates_when_source_id_matches_existing
        @calendar.existing = { "a" => "google-evt-1" }

        assert_sync(
          "upcoming" => [
            event_payload(id: "a", title: "Updated"),
            event_payload(id: "b", title: "New")
          ]
        )

        assert_equal "google-evt-1", @calendar.upserts[0][0]
        assert_equal "Updated", @calendar.upserts[0][1].title
        assert_nil @calendar.upserts[1][0]
      end

      def test_returns_true_with_no_upserts_when_upcoming_empty
        assert_sync("upcoming" => [])

        assert_empty @calendar.upserts
      end

      def test_returns_false_and_skips_upserts_on_list_error
        @calendar.list_error = Google::Apis::ServerError.new("boom")

        refute_sync("upcoming" => [event_payload(id: "a")])

        assert_empty @calendar.upserts
      end

      def test_returns_false_when_fetch_yields_nil
        refute_sync(nil)

        assert_empty @calendar.upserts
      end

      def test_returns_false_when_any_upsert_fails
        @calendar.upsert_error = Google::Apis::ServerError.new("nope")

        refute_sync("upcoming" => [event_payload(id: "a")])

        assert_equal 1, @calendar.upserts.size
      end

      def test_strips_html_from_body
        assert_sync(
          "upcoming" => [
            event_payload(
              id: "a",
              body: "<div><p>Hello <strong>world</strong></p>\n<p>More</p></div>"
            )
          ]
        )

        assert_equal "Hello world\nMore", @calendar.upserts[0][1].description
      end

      def test_formats_text_address_location
        assert_sync(
          "upcoming" => [
            event_payload(
              id: "a",
              location: {
                "addressTitle" => "Town Hall",
                "addressLine1" => "1471 Highland Ave",
                "addressLine2" => "Needham, MA 02492",
                "addressCountry" => ""
              }
            )
          ]
        )

        assert_equal "Town Hall, 1471 Highland Ave, Needham, MA 02492",
                     @calendar.upserts[0][1].location
      end

      def test_skips_blank_address_parts_and_lat_lng
        assert_sync(
          "upcoming" => [
            event_payload(
              id: "a",
              location: {
                "mapLat" => 42.28,
                "mapLng" => -71.24,
                "addressTitle" => "",
                "addressLine1" => "",
                "addressLine2" => "",
                "addressCountry" => ""
              }
            )
          ]
        )

        assert_nil @calendar.upserts[0][1].location
      end

      def test_converts_unix_ms_to_utc_iso_with_z_suffix
        assert_sync(
          "upcoming" => [
            event_payload(id: "a", startDate: 1779835500078, endDate: 1779840000078)
          ]
        )

        event = @calendar.upserts[0][1]
        assert_equal "2026-05-26T22:45:00Z", event.start_at
        assert_equal "2026-05-27T00:00:00Z", event.end_at
      end

      def test_prepends_base_url_to_relative_full_url
        assert_sync(
          "upcoming" => [event_payload(id: "a", fullUrl: "/events/needham-bike-moms-1")]
        )

        assert_equal "https://www.letsbikeneedham.com/events/needham-bike-moms-1",
                     @calendar.upserts[0][1].url
      end

      def test_timezone_is_always_iana
        assert_sync("upcoming" => [event_payload(id: "a")])

        assert_equal "America/New_York", @calendar.upserts[0][1].timezone
      end

      private

      def event_payload(**overrides)
        overrides.transform_keys!(&:to_s)

        {
          "id" => overrides.fetch("id"),
          "title" => overrides.fetch("title") { "Event #{overrides.fetch("id")}" },
          "body" => overrides.fetch("body", ""),
          "fullUrl" => overrides.fetch("fullUrl") { "/events/#{overrides.fetch("id")}" },
          "startDate" => overrides.fetch("startDate", 1779835500078),
          "endDate" => overrides.fetch("endDate", 1779840000078),
          "location" => overrides.fetch("location", {
            "addressTitle" => "",
            "addressLine1" => "",
            "addressLine2" => "",
            "addressCountry" => ""
          })
        }
      end

      def run_sync(response)
        with_server(response) do |endpoint|
          fetcher = LetsBike.new(endpoint: endpoint)
          runner = Runner.new(calendar: @calendar, calendar_id: "events-cal-id", fetcher: fetcher)
          runner.call
        end
      end

      def assert_sync(response)
        assert(run_sync(response))
      end

      def refute_sync(response)
        refute(run_sync(response))
      end
    end
  end
end
