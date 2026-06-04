# frozen_string_literal: true

require_relative 'api_client'

module FinanceTracker
  module Services
    class CreateAccount
      class InvalidAccount < StandardError; end

      def initialize(config, current_session: nil)
        @client = ApiClient.new(config)
        @current_session = current_session
      end

      def call(email:, username:, password:)
        response = @client.post('/api/v1/accounts', { email: email, username: username, password: password })

        # If the API returned account data including an account_api_token, persist it into session
        begin
          account = FinanceTracker::Account.from_api(response)
          @current_session.current_account = account if @current_session && account
        rescue StandardError
          # ignore parsing/persistence errors — keep original behavior
        end

        response
      rescue ApiClient::ApiError => e
        raise InvalidAccount, e.message
      end
    end
  end
end