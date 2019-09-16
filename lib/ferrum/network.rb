# frozen_string_literal: true

require "ferrum/network/exchange"
require "ferrum/network/intercepted_request"

module Ferrum
  class Network
    CLEAR_TYPE = %i[traffic cache].freeze
    AUTHORIZE_TYPE = %i[server proxy].freeze
    RESOURCE_TYPES = %w[Document Stylesheet Image Media Font Script TextTrack
                        XHR Fetch EventSource WebSocket Manifest
                        SignedExchange Ping CSPViolationReport Other].freeze

    attr_reader :traffic, :exchange

    def initialize(page)
      @page = page
      @traffic = []
      @exchange = nil
    end

    def status
      @exchange&.response&.status
    end

    def clear(type)
      unless CLEAR_TYPE.include?(type)
        raise ArgumentError, ":type should be in #{CLEAR_TYPE}"
      end

      if type == :traffic
        @traffic.clear
      else
        @page.command("Network.clearBrowserCache")
      end

      true
    end

    def intercept(pattern: "*", resource_type: nil)
      pattern = { urlPattern: pattern }
      if resource_type && RESOURCE_TYPES.include?(resource_type.to_s)
        pattern[:resourceType] = resource_type
      end

      @page.command("Network.setRequestInterception", patterns: [pattern])
    end

    def authorize(user:, password:, type: :server)
      unless AUTHORIZE_TYPE.include?(type)
        raise ArgumentError, ":type should be in #{AUTHORIZE_TYPE}"
      end

      @authorized_ids ||= {}
      @authorized_ids[type] ||= []

      intercept

      @page.on(:request) do |request, index, total|
        if request.auth_challenge?(type)
          response = authorized_response(@authorized_ids[type],
                                         request.interception_id,
                                         user, password)

          @authorized_ids[type] << request.interception_id
          request.continue(authChallengeResponse: response)
        elsif index + 1 < total
          next # There are other callbacks that can handle this, skip
        else
          request.continue
        end
      end
    end

    def subscribe
      @page.on("Network.requestWillBeSent") do |params|
        # On redirects Chrome doesn't change `requestId`
        if exchange = find_by(params["requestId"])
          exchange.build_request(params)
        else
          exchange = Network::Exchange.new(params)
          @exchange = exchange if exchange.navigation_request?(@page.frame_id)
          @traffic << exchange
        end
      end

      @page.on("Network.responseReceived") do |params|
        if exchange = find_by(params["requestId"])
          exchange.build_response(params)
        end
      end

      @page.on("Network.loadingFinished") do |params|
        exchange = find_by(params["requestId"])
        if exchange && exchange.response
          exchange.response.body_size = params["encodedDataLength"]
        end
      end

      @page.on("Log.entryAdded") do |params|
        entry = params["entry"] || {}
        if entry["source"] == "network" &&
            entry["level"] == "error" &&
            exchange = find_by(entry["networkRequestId"])
          exchange.build_error(entry)
        end
      end
    end

    def authorized_response(ids, interception_id, username, password)
      if ids.include?(interception_id)
        { response: "CancelAuth" }
      elsif username && password
        { response: "ProvideCredentials",
          username: username,
          password: password }
      else
        { response: "CancelAuth" }
      end
    end

    def find_by(request_id)
      @traffic.find { |e| e.request.id == request_id }
    end
  end
end
