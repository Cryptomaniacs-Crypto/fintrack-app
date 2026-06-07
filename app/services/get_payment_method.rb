# frozen_string_literal: true

require_relative 'api_client'
require_relative '../models/wallet'

module FinanceTracker
  module Services
    class GetPaymentMethod
      class NotFoundError < StandardError; end

      def initialize(config = nil)
        @client = ApiClient.new(config)
      end

      def call(wallet_id:, auth_token:)
        response = @client.get("/api/v1/wallets/#{wallet_id}", auth_token: auth_token)
        Wallet.from_api(response)
      rescue ApiClient::ApiError => e
        raise NotFoundError, e.message if e.status == 404

        raise
      end
    end
  end
end
