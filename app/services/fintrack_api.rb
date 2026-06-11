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

      # --- Friends (one-way contact list) ---

      def list_friends(auth_token:, account_api_token: nil)
        @client.get('/api/v1/friends', auth_token: auth_token, account_api_token: account_api_token)
      end

      def add_friend(username, auth_token:, account_api_token: nil)
        @client.post('/api/v1/friends', { username: username },
                     auth_token: auth_token, account_api_token: account_api_token)
      end

      def remove_friend(username, auth_token:, account_api_token: nil)
        @client.delete("/api/v1/friends/#{username}", auth_token: auth_token, account_api_token: account_api_token)
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

      # Replaces the bill's items + tax/service. payload: { title?, tax_percent?,
      # service_percent?, items: [{ name, amount, sharer_usernames: [...] }] }
      def update_bill_split(id, payload, auth_token:, account_api_token: nil)
        @client.patch("/api/v1/bill-splits/#{id}", payload, auth_token: auth_token, account_api_token: account_api_token)
      end

      def delete_bill_split(id, auth_token:, account_api_token: nil)
        @client.delete("/api/v1/bill-splits/#{id}", auth_token: auth_token, account_api_token: account_api_token)
      end

      # Confirm-and-send a draft to its participants. wallet_id (optional) records
      # the owner's upfront expense for the grand total.
      def send_bill_split(id, wallet_id: nil, auth_token:, account_api_token: nil)
        @client.post("/api/v1/bill-splits/#{id}/send", { wallet_id: wallet_id },
                     auth_token: auth_token, account_api_token: account_api_token)
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

      # A participant records payment from their wallet (+ optional base64 proof).
      def pay_bill_split(id, wallet_id:, proof_base64: nil, proof_content_type: nil, auth_token:, account_api_token: nil)
        @client.post(
          "/api/v1/bill-splits/#{id}/pay",
          { wallet_id: wallet_id, proof_base64: proof_base64, proof_content_type: proof_content_type },
          auth_token: auth_token, account_api_token: account_api_token
        )
      end

      # The owner confirms a participant's payment, recording income on their wallet.
      def confirm_bill_split_payment(id, participant_id:, wallet_id:, auth_token:, account_api_token: nil)
        @client.post(
          "/api/v1/bill-splits/#{id}/participants/#{participant_id}/confirm",
          { wallet_id: wallet_id },
          auth_token: auth_token, account_api_token: account_api_token
        )
      end

      # Fetch a participant's proof image as { content_type, image_base64 }.
      def bill_split_proof(id, participant_id:, auth_token:, account_api_token: nil)
        @client.get(
          "/api/v1/bill-splits/#{id}/participants/#{participant_id}/proof",
          auth_token: auth_token, account_api_token: account_api_token
        )
      end

      # Owner uploads the bill's source-receipt photo.
      def upload_bill_split_receipt(id, image_base64:, content_type:, auth_token:, account_api_token: nil)
        @client.post(
          "/api/v1/bill-splits/#{id}/receipt",
          { image_base64: image_base64, content_type: content_type },
          auth_token: auth_token, account_api_token: account_api_token
        )
      end

      # Any participant fetches the receipt as { content_type, image_base64 }.
      def bill_split_receipt(id, auth_token:, account_api_token: nil)
        @client.get(
          "/api/v1/bill-splits/#{id}/receipt",
          auth_token: auth_token, account_api_token: account_api_token
        )
      end

      def delete_bill_split_receipt(id, auth_token:, account_api_token: nil)
        @client.delete(
          "/api/v1/bill-splits/#{id}/receipt",
          auth_token: auth_token, account_api_token: account_api_token
        )
      end
    end
  end
end
