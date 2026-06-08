# frozen_string_literal: true

require_relative 'api_client'

module FinanceTracker
  module Services
    class CreateCategory
      def initialize(config = nil)
        @client = ApiClient.new(config)
      end

      def call(auth_token:, name:)
        @client.post('/api/v1/categories', { name: name.to_s.strip }, auth_token: auth_token)
      end
    end
  end
end
