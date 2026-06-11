# frozen_string_literal: true

require_relative 'api_client'

module FinanceTracker
  module Services
    # Talks to the API for the per-user home cover photo (banner).
    class BannerImage
      def initialize(config = nil)
        @client = ApiClient.new(config)
      end

      def upload(username:, image_base64:, content_type:, auth_token:, account_api_token: nil)
        @client.put(
          "/api/v1/accounts/#{username}/banner",
          { image_base64: image_base64, content_type: content_type },
          auth_token: auth_token, account_api_token: account_api_token
        )
      end

      def fetch(username:, auth_token:, account_api_token: nil)
        @client.get("/api/v1/accounts/#{username}/banner",
                    auth_token: auth_token, account_api_token: account_api_token)
      end

      def remove(username:, auth_token:, account_api_token: nil)
        @client.delete("/api/v1/accounts/#{username}/banner",
                       auth_token: auth_token, account_api_token: account_api_token)
      end
    end
  end
end
