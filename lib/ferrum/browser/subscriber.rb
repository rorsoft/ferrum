# frozen_string_literal: true

require "concurrent-ruby"

module Ferrum
  class Browser
    class Subscriber
      include Concurrent::Async

      def self.build(size)
        (0..size).map { new }
      end

      def initialize
        super
        @on = Concurrent::Hash.new { |h, k| h[k] = Concurrent::Array.new }
      end

      def on(event, handler_type: :any_times, &block)
        send("handle_#{handler_type}", event, &block)
        true
      end

      def subscribed?(event)
        @on.key?(event)
      end

      def call(message)
        method, params = message.values_at("method", "params")
        total = @on[method].size
        @on[method].each_with_index do |block, index|
          # If there are a few callback we provide current index and total
          block.call(params, index, total)
        end
      end

      private

      def handle_any_times(event, &block)
        @on[event] << block
      end

      def handle_once(event, &block)
        @once ||= Concurrent::Hash.new { |h, k| h[k] = Concurrent::Array.new }
        handler = Proc.new do |args|
          _block = @on[event].find { |_block| @once[event].find { |_handler| _handler.object_id == _block.object_id } }
          @once[event] = @once[event].reject { |_block| _block.object_id == _block.object_id }
          @on[event] = @on[event].reject { |_block| _block.object_id == _block.object_id }
          block.call(args)
        end
        @once[event] << handler
        @on[event] << handler
      end
    end
  end
end
