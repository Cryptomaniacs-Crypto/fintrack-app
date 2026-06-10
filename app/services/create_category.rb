# frozen_string_literal: true

require_relative 'api_client'

module FinanceTracker
  module Services
    class CreateCategory
      def initialize(config = nil)
        @client = ApiClient.new(config)
      end

      def call(auth_token:, name:, description: nil)
        body = { name: name.to_s.strip }
        body[:description] = description.to_s.strip unless description.to_s.strip.empty?
        @client.post('/api/v1/categories', body, auth_token: auth_token)
      end
    end
  end
end
