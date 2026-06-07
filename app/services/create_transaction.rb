# frozen_string_literal: true

require_relative 'api_client'

module FinanceTracker
  module Services
    class CreateTransaction
      class InvalidInput < StandardError; end

      def initialize(config = nil)
        @client = ApiClient.new(config)
      end

      def call(auth_token:, wallet_id:, title:, transaction_type:, amount:, transaction_date:,
               category_id: nil, note: nil)
        signed_amount = build_amount(transaction_type, amount)

        payload = {
          wallet_id: wallet_id,
          title: title.to_s.strip,
          amount: signed_amount,
          transaction_date: transaction_date
        }
        payload[:category_id] = category_id.to_i if category_id.to_s.strip != ''
        payload[:note] = note.to_s.strip unless note.to_s.strip.empty?

        @client.post('/api/v1/transactions', payload, auth_token: auth_token)
      end

      private

      def build_amount(transaction_type, raw_amount)
        parsed = Float(raw_amount.to_s.strip, exception: false)
        raise InvalidInput, 'Amount must be a valid number' unless parsed
        raise InvalidInput, 'Amount must be greater than zero' unless parsed.positive?

        transaction_type == 'expense' ? "-#{parsed}" : parsed.to_s
      end
    end
  end
end
