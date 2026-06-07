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

      def list_split_agreements(auth_token:, account_api_token: nil)
        @client.get('/api/v1/split-agreements', auth_token: auth_token, account_api_token: account_api_token)
      end

      def list_transactions(auth_token: nil, account_api_token: nil)
        @client.get('/api/v1/transactions', auth_token: auth_token, account_api_token: account_api_token)
      rescue StandardError
        []
      end

      def create_split_agreement(payload, auth_token:, account_api_token: nil)
        @client.post('/api/v1/split-agreements', payload, auth_token: auth_token, account_api_token: account_api_token)
      end

      def get_split_agreement(agreement_id, auth_token:, account_api_token: nil)
        @client.get("/api/v1/split-agreements/#{agreement_id}", auth_token: auth_token, account_api_token: account_api_token)
      end

      def agree_split_agreement(agreement_id, auth_token:, account_api_token: nil)
        @client.post("/api/v1/split-agreements/#{agreement_id}/agree", {}, auth_token: auth_token, account_api_token: account_api_token)
      end

      def mark_paid_split_agreement(agreement_id, auth_token:, account_api_token: nil)
        @client.post("/api/v1/split-agreements/#{agreement_id}/mark-paid", {}, auth_token: auth_token, account_api_token: account_api_token)
      end

      def dispute_split_agreement(agreement_id, reason:, auth_token:, account_api_token: nil)
        @client.post(
          "/api/v1/split-agreements/#{agreement_id}/dispute",
          { reason: reason },
          auth_token: auth_token,
          account_api_token: account_api_token
        )
      end

      def finalize_split_agreement(agreement_id, auth_token:, account_api_token: nil)
        @client.post("/api/v1/split-agreements/#{agreement_id}/finalize", {}, auth_token: auth_token, account_api_token: account_api_token)
      end
    end
  end
end
