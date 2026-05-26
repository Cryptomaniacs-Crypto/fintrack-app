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

      def list_transactions(auth_token:)
        get_json('/api/v1/transactions', auth_token: auth_token)
      rescue StandardError
        []
      end

      private

      def get_json(path, auth_token:)
        uri = URI.join(@base_url, path)
        request = Net::HTTP::Get.new(uri)
        request['Authorization'] = "Bearer #{auth_token}"
        response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https') do |http|
          http.request(request)
        end

        unless response.is_a?(Net::HTTPSuccess)
          raise "Fintrack API error: #{response.code}"
        end

        JSON.parse(response.body)
      end
    end
  end
end
