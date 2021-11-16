# frozen_string_literal: true

module Ferrum
  module Utils
    module Stream
      module_function

      def from(client)
        tap { @client = client }
      end

      def fetch(handle, path:, encoding:)
        if path.nil?
          stream_to_memory(handle, encoding: encoding)
        else
          stream_to_file(handle, path: path)
        end
      end

      def stream_to_file(handle, path:)
        File.open(path, "wb") { |f| stream_to(handle, f) }
        true
      end

      def stream_to_memory(handle, encoding:)
        data = String.new("") # Mutable string has << and compatible to File
        stream_to(handle, data)
        encoding == :base64 ? Base64.encode64(data) : data
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
