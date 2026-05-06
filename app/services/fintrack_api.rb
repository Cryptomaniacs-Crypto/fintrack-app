# frozen_string_literal: true

require 'json'
require 'net/http'
require 'uri'

module FinanceTracker
  module Services
    class FintrackApi
      def initialize(base_url: ENV.fetch('FINTRACK_API_URL', 'http://localhost:9292'))
        @base_url = base_url
      end

      def list_transactions
        get_json('/api/v1/transactions')
      rescue StandardError
        []
      end

      private

      def get_json(path)
        uri = URI.join(@base_url, path)
        response = Net::HTTP.get_response(uri)

        unless response.is_a?(Net::HTTPSuccess)
          raise "Fintrack API error: #{response.code}"
        end

        JSON.parse(response.body)
      end
    end
  end
end
