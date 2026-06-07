# frozen_string_literal: true

require_relative 'api_client'
require_relative '../models/transaction'

module FinanceTracker
  module Services
    class GetTransaction
      class NotFoundError < StandardError; end

      def initialize(config = nil)
        @client = ApiClient.new(config)
      end

      def call(transaction_id:, auth_token:)
        data = @client.get("/api/v1/transactions/#{transaction_id}", auth_token: auth_token)
        FinanceTracker::Transaction.from_api(data)
      rescue ApiClient::ApiError => e
        raise NotFoundError, e.message if e.status == 404

        raise
      end
    end
  end
end
