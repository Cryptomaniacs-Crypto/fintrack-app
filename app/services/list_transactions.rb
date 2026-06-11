# frozen_string_literal: true

require_relative 'api_client'
require_relative '../models/transaction'

module FinanceTracker
  module Services
    class ListTransactions
      def initialize(config = nil)
        @client = ApiClient.new(config)
      end

      def call(auth_token:, wallet_id: nil)
        params = wallet_id ? { wallet_id: wallet_id } : {}
        response = @client.get('/api/v1/transactions', params: params, auth_token: auth_token)
        Array(response['data']).map { |entry| FinanceTracker::Transaction.from_api(entry) }
      end
    end
  end
end
