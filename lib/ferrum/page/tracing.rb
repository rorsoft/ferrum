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
      ].freeze
      EXCLUDED_CATEGORIES = %w[
        *
      ].freeze

      def initialize(client:)
        self.client = client
      end

      def start(trace_options: {}, **options)
        self.options = OpenStruct.new(**options)
        self.options.promise = Concurrent::Promises.resolvable_future
        subscribe_on_tracing_event
        inner_start(trace_options)
      end

      def stop
        client.command("Tracing.end")
        options.promise.value!
      end

      private

      attr_accessor :client, :options

      def inner_start(trace_options)
        client.command(
          "Tracing.start",
          transferMode: "ReturnAsStream",
          traceConfig: {
            includedCategories: included_categories,
            excludedCategories: EXCLUDED_CATEGORIES
          },
          **trace_options
        )
      end

      def included_categories
        included_categories = INCLUDED_CATEGORIES
        included_categories = INCLUDED_CATEGORIES | ["disabled-by-default-devtools.screenshot"] if options.screenshots
        included_categories
      end

      def subscribe_on_tracing_event
        client.on("Tracing.tracingComplete") do |event, index|
          next if index.to_i != 0

          options.promise.fulfill(stream(event.fetch("stream")))
        rescue StandardError => e
          options.promise.reject(e)
        end
      end

      def stream(handle)
        Utils::Stream.for(client).fetch(handle, encoding: options.encoding, path: options.path)
      end
    end
  end
end
