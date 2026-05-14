# frozen_string_literal: true

require_relative 'api_client'

module FinanceTracker
  module Services
    # Lists payment methods for the logged-in account.
    class ListPaymentMethods
      def initialize(base_url: ENV.fetch('FINTRACK_API_URL', 'http://localhost:9292'))
        @client = ApiClient.new(base_url: base_url)
      end

      def call(current_account_id:)
        @client.get('/api/v1/wallets', params: { current_account_id: current_account_id }).fetch('data', [])
      end
    end
  end
end
