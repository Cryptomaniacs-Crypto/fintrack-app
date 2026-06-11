# frozen_string_literal: true

require_relative 'api_client'
require_relative '../models/account'

module FinanceTracker
  module Services
    class GetAccount
      def initialize(base_url: ENV.fetch('FINTRACK_API_URL', 'http://localhost:9292'))
        @client = ApiClient.new(base_url: base_url)
      end

      def call(username, auth_token:, account_api_token: nil)
        FinanceTracker::Account.from_api(
          @client.get("/api/v1/accounts/#{username}", auth_token: auth_token, account_api_token: account_api_token)
        )
      end
    end
  end
end