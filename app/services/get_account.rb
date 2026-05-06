# frozen_string_literal: true

require_relative 'api_client'

module FinanceTracker
  module Services
    class GetAccount
      def initialize(base_url: ENV.fetch('FINTRACK_API_URL', 'http://localhost:9292'))
        @client = ApiClient.new(base_url: base_url)
      end

      def call(username, current_account_id:)
        @client.get("/api/v1/accounts/#{username}", params: { current_account_id: current_account_id })
      end
    end
  end
end