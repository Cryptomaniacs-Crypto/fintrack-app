# frozen_string_literal: true

require_relative 'api_client'
require_relative '../models/payment_method'

module FinanceTracker
  module Services
    # Lists payment methods for the logged-in account.
    class ListPaymentMethods
      def initialize(base_url: ENV.fetch('FINTRACK_API_URL', 'http://localhost:9292'))
        @client = ApiClient.new(base_url: base_url)
      end

      def call(auth_token:)
        data = @client.get('/api/v1/wallets', auth_token: auth_token).fetch('data', [])
        FinanceTracker::PaymentMethod.list_from_api(data)
      end
    end
  end
end
