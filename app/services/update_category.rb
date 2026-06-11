# frozen_string_literal: true

require_relative 'api_client'

module FinanceTracker
  module Services
    class UpdateCategory
      def initialize(config = nil)
        @client = ApiClient.new(config)
      end

      def call(auth_token:, category_id:, name:, description: nil)
        payload = { name: name.to_s.strip }
        payload[:description] = description.to_s.strip unless description.to_s.strip.empty?
        @client.patch("/api/v1/categories/#{category_id}", payload, auth_token: auth_token)
      end
    end
  end
end
