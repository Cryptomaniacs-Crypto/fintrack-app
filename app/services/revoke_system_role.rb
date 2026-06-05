# frozen_string_literal: true

module FinanceTracker
  module Services
    class RevokeSystemRole
      class InvalidInput < StandardError; end

      VALID_ROLES = %w[admin creator member].freeze

      def call(auth_token:, target_username:, role_name:, account_api_token: nil)
        raise InvalidInput, "Role must be one of: #{VALID_ROLES.join(', ')}" unless VALID_ROLES.include?(role_name)

        raise InvalidInput, 'Role revocation is not supported by the current API'
      end
    end
  end
end# frozen_string_literal: true

require_relative 'api_client'

module FinanceTracker
  module Services
    class RevokeSystemRole
      class InvalidInput < StandardError; end

      VALID_ROLES = %w[admin creator member].freeze

        def initialize(base_url: ENV.fetch('FINTRACK_API_URL', 'http://localhost:9292'))
        @client = ApiClient.new(base_url: base_url)
      end

      def call(auth_token:, target_username:, role_name:, account_api_token: nil)
        raise InvalidInput, "Role must be one of: #{VALID_ROLES.join(', ')}" unless VALID_ROLES.include?(role_name)

        @client.delete(
          "/api/v1/accounts/#{target_username}/roles/#{role_name}",
          nil,
          auth_token: auth_token,
          account_api_token: account_api_token
        )
      end
    end
  end
end