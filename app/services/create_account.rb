# frozen_string_literal: true

require_relative 'api_client'

module FinanceTracker
  module Services
    class CreateAccount
      class InvalidAccount < StandardError; end

      def initialize(config)
        @client = ApiClient.new(config)
      end

      def call(email:, username:, password:)
        @client.post('/api/v1/accounts', { email: email, username: username, password: password })
      rescue ApiClient::ApiError => e
        raise InvalidAccount, e.message
      end
    end
  end
end