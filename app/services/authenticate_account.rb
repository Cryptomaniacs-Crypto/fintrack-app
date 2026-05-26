# frozen_string_literal: true

require_relative 'api_client'
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

        response = @client.post('/api/v1/auth/authentication', { username: username, password: password })

        account = FinanceTracker::Account.from_auth(response)

        @current_session.current_account = account if @current_session

        { account: account.account_info, auth_token: account.auth_token }
      rescue ApiClient::ApiError => e
        raise UnauthorizedError, "Authentication failed: #{e.message}" if e.status == 403

        raise
      end
    end
  end
end
