# frozen_string_literal: true

require_relative 'api_client'

module FinanceTracker
  module Services
    class DeleteTransaction
      class NotFoundError < StandardError; end

      def initialize(config = nil)
        @client = ApiClient.new(config)
      end

      def call(transaction_id:, auth_token:)
        @client.delete("/api/v1/transactions/#{transaction_id}", auth_token: auth_token)
      rescue ApiClient::ApiError => e
        raise NotFoundError, e.message if e.status == 404

        raise
      end
    end
  end
end
