# frozen_string_literal: true

require_relative 'api_client'

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

        # API returns: { type: 'authenticated_account',
        #                attributes: { account: <Account.to_json envelope>, auth_token: '...' } }
        # where Account.to_json envelope is { data: { type: 'account', attributes: {id, username, email, avatar} } }
        top_attributes = response.fetch('attributes', {})
        auth_token = top_attributes['auth_token']
        account_envelope = top_attributes['account'] || {}
        account_info = (account_envelope.dig('data', 'attributes') || {}).dup

        included = response['included'] || {}
        system_roles_array = included['system_roles'] || []
        account_info['system_roles'] = system_roles_array.map { |role| role['name'] }

        if @current_session
          account = FinanceTracker::Account.new(account_info, auth_token)
          @current_session.current_account = account
        end

        { account: account_info, auth_token: auth_token }
      rescue ApiClient::ApiError => e
        raise UnauthorizedError, "Authentication failed: #{e.message}" if e.status == 403

        raise
      end
    end
  end
end
