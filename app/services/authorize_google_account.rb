# frozen_string_literal: true

require_relative 'api_client'

module FinanceTracker
  module Services
    class AuthorizeGoogleAccount
      class AuthorizeError < StandardError; end

      def initialize(config = nil)
        @client = ApiClient.new(config)
      end

      # Exchange the Google authorization `code` with the API which performs
      # the token exchange/validation and returns account/auth tokens.
      def call(code)
        @client.post('/api/v1/auth/sso', { code: code })
      rescue ApiClient::ApiError => e
        raise AuthorizeError, e.message
      end
    end
  end
end
