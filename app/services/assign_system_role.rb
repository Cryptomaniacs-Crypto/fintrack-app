# frozen_string_literal: true

require_relative 'api_client'

module FinanceTracker
  module Services
    class AssignSystemRole
      class InvalidInput < StandardError; end

      VALID_ROLES = %w[admin creator member].freeze

        def initialize(base_url: ENV.fetch('FINTRACK_API_URL', 'http://localhost:9292'))
        @client = ApiClient.new(base_url: base_url)
      end

      def call(current_account_id:, target_username:, role_name:)
        raise InvalidInput, "Role must be one of: #{VALID_ROLES.join(', ')}" unless VALID_ROLES.include?(role_name)

        @client.authenticated_put(
          "/api/v1/accounts/#{target_username}/system_roles/#{role_name}",
          {},
          current_account_id: current_account_id
        )
      end
    end
  end
end