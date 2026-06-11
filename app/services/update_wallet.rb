# frozen_string_literal: true

require_relative 'api_client'

module FinanceTracker
  module Services
    class UpdateWallet
      def initialize(config = nil)
        @client = ApiClient.new(config)
      end

      def call(auth_token:, wallet_id:, name:, account_number: nil)
        payload = { name: name.to_s.strip }
        payload[:account_number] = account_number.to_s unless account_number.nil?
        @client.patch("/api/v1/wallets/#{wallet_id}", payload, auth_token: auth_token)
      end
    end
  end
end
