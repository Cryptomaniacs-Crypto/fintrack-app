# frozen_string_literal: true

require 'dry-validation'
require_relative 'form_base'

module FinanceTracker
  module Form
    PAYMENT_METHOD_TYPES = %w[cash bank_account credit_card debit_card e_wallet].freeze
    PAYMENT_METHODS_NEEDING_ACCOUNT_NUMBER =
      %w[bank_account credit_card debit_card e_wallet].freeze

    CreatePaymentMethod = Dry::Validation.Contract do
      params do
        required(:name).filled(:string, max_size?: 200)
        required(:method_type).filled(:string, included_in?: PAYMENT_METHOD_TYPES)
        optional(:account_number).maybe(:string, max_size?: 100)
        optional(:balance).maybe(:string)
      end

      # Cross-field rule: non-cash methods must carry an account/card number.
      rule(:account_number, :method_type) do
        method_type = values[:method_type]
        account_number = values[:account_number].to_s.strip

        if PAYMENT_METHODS_NEEDING_ACCOUNT_NUMBER.include?(method_type) && account_number.empty?
          key(:account_number).failure('is required for this payment method type')
        end
      end

      rule(:balance) do
        raw = value.to_s.strip
        next if raw.empty?

        parsed = Float(raw, exception: false)
        if parsed.nil?
          key.failure('must be a valid number')
        elsif parsed.negative?
          key.failure('must be zero or positive')
        end
      end
    end
  end
end
