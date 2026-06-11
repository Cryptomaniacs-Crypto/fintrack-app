# frozen_string_literal: true

require_relative 'api_client'

module FinanceTracker
  module Services
    class DeleteCategory
      class NotFoundError < StandardError; end
      class ForbiddenError < StandardError; end

      def initialize(config = nil)
        @client = ApiClient.new(config)
      end

      def call(auth_token:, category_id:)
        @client.delete("/api/v1/categories/#{category_id}", auth_token: auth_token)
      rescue ApiClient::ApiError => e
        raise NotFoundError if e.status == 404
        raise ForbiddenError if e.status == 403

        raise
      end
    end
  end
end
