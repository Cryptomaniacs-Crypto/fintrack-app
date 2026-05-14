# frozen_string_literal: true

require_relative 'api_client'

module FinanceTracker
  module Services
    # Creates a payment method through the FinTrack API.
    class CreatePaymentMethod
      class InvalidInput < StandardError; end

      METHOD_TYPES = {
        'cash' => 'Cash',
        'bank_account' => 'Bank Account',
        'credit_card' => 'Credit Card',
        'debit_card' => 'Debit Card',
        'e_wallet' => 'E-Wallet'
      }.freeze

      def initialize(base_url: ENV.fetch('FINTRACK_API_URL', 'http://localhost:9292'))
        @client = ApiClient.new(base_url: base_url)
      end

      def call(current_account_id:, name:, method_type:, account_number: nil, balance: nil)
        payload = build_payload(
          name: name,
          method_type: method_type,
          account_number: account_number,
          balance: balance
        )

        @client.authenticated_post('/api/v1/wallets', payload, current_account_id: current_account_id)
      end

      private

      def build_payload(name:, method_type:, account_number:, balance:)
        cleaned_name = name.to_s.strip
        cleaned_method_type = method_type.to_s.strip
        cleaned_account_number = account_number.to_s.strip
        cleaned_balance = balance.to_s.strip

        raise InvalidInput, 'Payment method name is required' if cleaned_name.empty?
        raise InvalidInput, 'Payment method name must be 200 characters or fewer' if cleaned_name.length > 200
        raise InvalidInput, 'Choose a valid payment method type' unless METHOD_TYPES.key?(cleaned_method_type)

        if requires_account_reference?(cleaned_method_type) && cleaned_account_number.empty?
          raise InvalidInput, 'Account/card number is required for this method type'
        end
        raise InvalidInput, 'Account/card number must be 100 characters or fewer' if cleaned_account_number.length > 100

        payload = {
          name: cleaned_name,
          method_type: cleaned_method_type
        }
        payload[:account_number] = cleaned_account_number unless cleaned_account_number.empty?
        payload[:balance] = normalize_balance(cleaned_balance) unless cleaned_balance.empty?
        payload
      end

      def normalize_balance(raw_value)
        parsed = Float(raw_value, exception: false)
        raise InvalidInput, 'Opening balance must be a valid number' unless parsed

        parsed.to_s
      end

      def requires_account_reference?(method_type)
        %w[bank_account credit_card debit_card e_wallet].include?(method_type)
      end
    end
  end
end
