# frozen_string_literal: true

require_relative 'api_client'

module FinanceTracker
  module Services
    # Renames the signed-in account's handle via the API.
    class UpdateUsername
      class UsernameTaken < StandardError; end
      class InvalidUsername < StandardError; end
      class UpdateError < StandardError; end

      def initialize(config = nil)
        @client = ApiClient.new(config)
      end

      def call(current_username:, new_username:, auth_token:, account_api_token: nil)
        @client.put(
          "/api/v1/accounts/#{current_username}",
          { username: new_username },
          auth_token: auth_token,
          account_api_token: account_api_token
        )
      rescue ApiClient::ApiError => e
        case e.status
        when 409 then raise UsernameTaken, e.message
        when 400 then raise InvalidUsername, e.message
        when 403 then raise UpdateError, 'You are not allowed to change this username'
        else raise UpdateError, e.message
        end
      end
    end
  end
end
