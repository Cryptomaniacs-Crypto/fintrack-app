# frozen_string_literal: true

require_relative 'api_client'
require_relative '../lib/signed_message'
require_relative '../models/account'

module FinanceTracker
  module Services
    class AuthenticateAccount
      class UnauthorizedError < StandardError; end

      def initialize(config = nil, current_session: nil)
        @client = ApiClient.new(config)
        @current_session = current_session
      end

      def call(username:, password:)
        raise UnauthorizedError, 'Username and password required' if username.to_s.strip.empty? || password.to_s.empty?

        # Sign the credentials: this POST carries no auth_token, so the API
        # requires a valid signature before it will process the body.
        signed = FinanceTracker::SignedMessage.sign({ username: username, password: password })
        response = @client.post('/api/v1/auth/authentication', signed)

        account = FinanceTracker::Account.from_auth(response)
        @current_session.current_account = account if @current_session

        {
          account: account.account_info,
          auth_token: account.auth_token,
          account_api_token: account.account_api_token
        }
      rescue ApiClient::ApiError => e
        raise UnauthorizedError, "Authentication failed: #{e.message}" if [401, 403].include?(e.status)

        raise
      end
    end
  end
end
