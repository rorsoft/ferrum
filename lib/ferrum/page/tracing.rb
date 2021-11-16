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
        path: nil,
        encoding: :base64,
        screenshots: false,
        options: {}
      )
        categories = INCLUDED_CATEGORIES.concat(["disabled-by-default-devtools.screenshot"]) if screenshots
        self.path = path
        self.promise = Concurrent::Promises.resolvable_future
        subscribe_on_tracing_event
        inner_start(options)
      end

      def stop
        client.command("Tracing.end")
        promise.value!
      end

      private

      attr_accessor :client, :path, :encoding, :promise

      def inner_start(options)
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

      def subscribe_on_tracing_event
        client.on("Tracing.tracingComplete") do |event, index|
          next if index.to_i != 0
          promise.fulfill(stream(event.fetch("stream")))
        rescue StandardError => e
          promise.reject(e)
        end
      end

      def stream(handle)
        Utils::Stream.from(client).fetch(handle, encoding: encoding, path: path)
      end
    end
  end
end
