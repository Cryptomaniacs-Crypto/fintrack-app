# frozen_string_literal: true

require_relative 'api_client'

module FinanceTracker
  module Services
    class UpdateTransaction
      class InvalidInput < StandardError; end

      def initialize(config = nil)
        @client = ApiClient.new(config)
      end

      def call(auth_token:, transaction_id:, title:, transaction_type:, amount:,
               transaction_date:, category_id: nil, note: nil)
        parsed = amount.to_f.abs
        raise InvalidInput, 'Amount must be greater than zero' unless parsed.positive?

        signed = transaction_type == 'expense' ? "-#{parsed}" : parsed.to_s

        payload = {
          title:            title.to_s.strip,
          amount:           signed,
          transaction_date: transaction_date,
          note:             note.to_s,
          category_id:      category_id.to_s.empty? ? nil : category_id
        }

        @client.patch("/api/v1/transactions/#{transaction_id}", payload, auth_token: auth_token)
      end
    end
  end
end
