# frozen_string_literal: true

module FinTrack
  # Authenticate user credentials against the FinTrack API.
  # Returns a hash safe for session storage: id, username, email, avatar, system_roles.
  class AuthenticateAccount
    class UnauthorizedError < StandardError; end

    def initialize(config)
      @client = ApiClient.new(config)
    end

    def call(username:, password:)
      raise UnauthorizedError, 'Username and password required' if
        username.to_s.strip.empty? || password.to_s.empty?

      response = @client.post('/auth/authentication', { username: username, password: password })
      attrs = response.fetch('data').fetch('attributes')
      role_names = (response['included']&.fetch('system_roles', []) || []).map { |r| r['name'] }
      attrs.merge('system_roles' => role_names)
    rescue ApiClient::ApiError => e
      raise UnauthorizedError, 'Invalid credentials' if e.status == 403

      raise
    end
  end
end
