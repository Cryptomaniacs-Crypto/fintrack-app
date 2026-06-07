# frozen_string_literal: true

require_relative 'api_client'

module FinanceTracker
  module Services
    class AssignSystemRole
      class InvalidInput < StandardError; end

      VALID_ROLES = %w[admin creator member].freeze

      def initialize(config = nil)
        @client = ApiClient.new(config)
      end

      def call(auth_token:, target_username:, role_name:, account_api_token: nil)
        raise InvalidInput, "Role must be one of: #{VALID_ROLES.join(', ')}" unless VALID_ROLES.include?(role_name)

        @client.post(
          "/api/v1/accounts/#{target_username}/roles/#{role_name}",
          {},
          auth_token: auth_token,
          account_api_token: account_api_token
        )
      end
    end
  end
end
