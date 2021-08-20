# frozen_string_literal: true

module Ferrum
  class Browser
    # chrome://tracing
    class Tracing
      DEFAULT_CATEGORIES = %w[
        -*
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

      def initialize(client:)
        self.client = client
      end

      def start(path: '', screenshots: false, categories: DEFAULT_CATEGORIES)
        raise "Cannot start recording trace while already recording trace." if recording
        categories = categories.concat(["disabled-by-default-devtools.screenshot"]) if screenshots
        self.path = path
        self.recording = true
        @client.command("Tracing.start", transferMode: "ReturnAsStream", categories: categories.join(','))
      end

      def stop
        @client.on("Tracing.tracingComplete", handler_type: :once) do |event|
          stream_to_file(event.fetch("stream"), path: path)
        end
        @client.command("Tracing.end")
        self.recording = false
      end

      private

      attr_accessor :client, :recording, :path

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
