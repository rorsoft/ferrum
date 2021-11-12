# frozen_string_literal: true

module Ferrum
  class Page
    class Tracing
      INCLUDED_CATEGORIES = %w[
        devtools.timeline
        v8.execute
        disabled-by-default-devtools.timeline
        disabled-by-default-devtools.timeline.frame
        toplevel
        blink.console
        blink.user_timing
        latencyInfo
        disabled-by-default-devtools.timeline.stack
        disabled-by-default-v8.cpu_profiler
        disabled-by-default-v8.cpu_profiler.hires
      ]
      EXCLUDED_CATEGORIES = %w[
        *
      ]

      def initialize(client:)
        self.client = client
      end

      def start(
        path: '',
        screenshots: false,
        options: {}
      )
        categories = INCLUDED_CATEGORIES.concat(["disabled-by-default-devtools.screenshot"]) if screenshots
        self.path = path
        client.command(
          "Tracing.start",
          transferMode: "ReturnAsStream",
          traceConfig: {
            includedCategories: INCLUDED_CATEGORIES,
            excludedCategories: EXCLUDED_CATEGORIES,
          },
          **options
        )
      end

      def stop
        client.on("Tracing.tracingComplete", handler_type: :once) do |event|
          stream_to_file(event.fetch("stream"), path: path)
        end
        client.command("Tracing.end")
      end

      private

      attr_accessor :client, :path

      # DRY lib/ferrum/page/screenshot.rb
      def stream_to_file(handle, path:)
        File.open(path, "wb") { |f| stream_to(handle, f) }
        true
      end

      def stream_to(handle, output)
        loop do
          result = @client.command("IO.read", handle: handle, size: 128 * 1024)
          data_chunk = result["data"]
          data_chunk = Base64.decode64(data_chunk) if result["base64Encoded"]
          output << data_chunk
          break if result["eof"]
        end
      end
    end
  end
end