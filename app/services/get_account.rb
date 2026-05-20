# frozen_string_literal: true

require_relative 'api_client'

module FinanceTracker
  module Services
    class GetAccount
      def initialize(base_url: ENV.fetch('FINTRACK_API_URL', 'http://localhost:9292'))
        @client = ApiClient.new(base_url: base_url)
      end

      def call(username, auth_token:)
        @client.get("/api/v1/accounts/#{username}", auth_token: auth_token)
      end
    end
  end
end