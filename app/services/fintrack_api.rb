# frozen_string_literal: true

require_relative 'api_client'

module FinanceTracker
  module Services
    class FintrackApi
      def initialize(base_url: ENV.fetch('FINTRACK_API_URL', 'http://localhost:9292'))
        @client = ApiClient.new(base_url: base_url)
      end

      def list_transactions(auth_token: nil, account_api_token: nil)
        @client.get('/api/v1/transactions', auth_token: auth_token, account_api_token: account_api_token)
      rescue StandardError
        []
      end
    end
  end
end
