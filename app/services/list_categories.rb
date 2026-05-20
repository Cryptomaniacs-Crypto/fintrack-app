# frozen_string_literal: true

require_relative 'api_client'

module FinanceTracker
  module Services
    # Lists transaction categories (global reference data).
    class ListCategories
      def initialize(base_url: ENV.fetch('FINTRACK_API_URL', 'http://localhost:9292'))
        @client = ApiClient.new(base_url: base_url)
      end

      def call
        @client.get('/api/v1/categories').fetch('data', [])
      end
    end
  end
end
