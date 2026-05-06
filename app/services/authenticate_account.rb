# frozen_string_literal: true

require_relative 'api_client'

module FinanceTracker
  module Services
    class AuthenticateAccount
      class UnauthorizedError < StandardError; end

      def initialize(config = nil)
        @client = ApiClient.new(config)
      end

      def call(username:, password:)
        raise UnauthorizedError, 'Username and password required' if username.to_s.strip.empty? || password.to_s.empty?

        response = @client.post('/api/v1/auth/authentication', { username: username, password: password })

        account = response.fetch('data', {}).fetch('attributes', {})
        included = response['included'] || {}
        system_roles_array = included['system_roles'] || []

        account.merge('system_roles' => system_roles_array.map { |role| role['name'] })
      rescue ApiClient::ApiError => e
        raise UnauthorizedError, "Authentication failed: #{e.message}" if e.status == 403

        raise
      end
    end
  end
end
