# frozen_string_literal: true

require_relative 'api_client'

module FinanceTracker
  module Services
    class FintrackApi
      def initialize(base_url: ENV.fetch('FINTRACK_API_URL', 'http://localhost:9292'))
        @client = ApiClient.new(base_url: base_url)
      end

      def account_exists?(username)
        @client.get("/api/v1/accounts/#{username}")
        true
      rescue ApiClient::ApiError => e
        return false if e.status == 404

        raise
      end

      def list_transactions(auth_token: nil, account_api_token: nil)
        @client.get('/api/v1/transactions', auth_token: auth_token, account_api_token: account_api_token)
      rescue StandardError
        []
      end

      # --- Bill Splits ---

      def list_bill_splits(auth_token:, account_api_token: nil)
        @client.get('/api/v1/bill-splits', auth_token: auth_token, account_api_token: account_api_token)
      end

      def create_bill_split(payload, auth_token:, account_api_token: nil)
        @client.post('/api/v1/bill-splits', payload, auth_token: auth_token, account_api_token: account_api_token)
      end

      def get_bill_split(id, auth_token:, account_api_token: nil)
        @client.get("/api/v1/bill-splits/#{id}", auth_token: auth_token, account_api_token: account_api_token)
      end

      # Replaces the bill's dishes + tax/service. payload: { title?, tax_percent?,
      # service_percent?, items: [{ name, amount, sharer_usernames: [...] }] }
      def update_bill_split(id, payload, auth_token:, account_api_token: nil)
        @client.patch("/api/v1/bill-splits/#{id}", payload, auth_token: auth_token, account_api_token: account_api_token)
      end

      def delete_bill_split(id, auth_token:, account_api_token: nil)
        @client.delete("/api/v1/bill-splits/#{id}", auth_token: auth_token, account_api_token: account_api_token)
      end

      # Confirm-and-send a draft to its participants.
      def send_bill_split(id, auth_token:, account_api_token: nil)
        @client.post("/api/v1/bill-splits/#{id}/send", {}, auth_token: auth_token, account_api_token: account_api_token)
      end

      def agree_bill_split(id, auth_token:, account_api_token: nil)
        @client.post("/api/v1/bill-splits/#{id}/agree", {}, auth_token: auth_token, account_api_token: account_api_token)
      end

      def reject_bill_split(id, reason:, auth_token:, account_api_token: nil)
        @client.post(
          "/api/v1/bill-splits/#{id}/reject",
          { reason: reason },
          auth_token: auth_token,
          account_api_token: account_api_token
        )
      end

      def settle_bill_split(id, auth_token:, account_api_token: nil)
        @client.post("/api/v1/bill-splits/#{id}/settle", {}, auth_token: auth_token, account_api_token: account_api_token)
      end
    end
  end
end
