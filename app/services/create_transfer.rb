# frozen_string_literal: true

require_relative 'api_client'

module FinanceTracker
  module Services
    # Records a wallet-to-wallet transfer through the API's atomic /transfers
    # endpoint. Sends a single request; the API creates both legs (source
    # expense + destination income) inside one DB transaction, so a failure
    # can never leave the books half-updated.
    class CreateTransfer
      class InvalidInput < StandardError; end

      def initialize(config = nil)
        @client = ApiClient.new(config)
      end

      # rubocop:disable Metrics/ParameterLists
      def call(auth_token:, from_wallet_id:, to_wallet_id:, amount:, title:, transaction_date:, note: nil)
        payload = {
          wallet_id: from_wallet_id,
          to_wallet_id: to_wallet_id,
          title: title.to_s.strip,
          amount: validate_amount(amount),
          transaction_date: transaction_date
        }
        payload[:note] = note.to_s.strip unless note.to_s.strip.empty?

        @client.post('/api/v1/transfers', payload, auth_token: auth_token)
      end
      # rubocop:enable Metrics/ParameterLists

      private

      # Amount is sent unsigned; the API applies the sign per leg.
      def validate_amount(raw_amount)
        parsed = Float(raw_amount.to_s.strip, exception: false)
        raise InvalidInput, 'Amount must be a valid number' unless parsed
        raise InvalidInput, 'Amount must be greater than zero' unless parsed.positive?

        parsed.to_s
      end
    end
  end
end
