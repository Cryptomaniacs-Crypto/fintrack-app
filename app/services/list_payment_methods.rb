# frozen_string_literal: true

require_relative 'api_client'

module FinanceTracker
  module Services
    # Lists payment methods for the logged-in account.
    class ListPaymentMethods
      def initialize(base_url: ENV.fetch('FINTRACK_API_URL', 'http://localhost:9292'))
        @client = ApiClient.new(base_url: base_url)
      end

      def call(auth_token:)
        @client.get('/api/v1/wallets', auth_token: auth_token).fetch('data', [])
      end
    end
  end
end
