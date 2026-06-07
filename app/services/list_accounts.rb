# frozen_string_literal: true

require_relative 'api_client'
require_relative '../models/account'

module FinanceTracker
  module Services
    class ListAccounts
      class ForbiddenError < StandardError; end

      def initialize(config = nil)
        @client = ApiClient.new(config)
      end

      def call(auth_token:, role: nil, sort: nil)
        params = { role: role, sort: sort }.compact
        response = @client.get('/api/v1/accounts', params: params, auth_token: auth_token)
        response['data'].map { |entry| Account.from_api(entry) }
      rescue ApiClient::ApiError => e
        raise ForbiddenError, e.message if e.status == 403

        raise
      end
    end
  end
end
