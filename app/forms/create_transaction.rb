# frozen_string_literal: true

require 'dry-validation'
require_relative 'form_base'

module FinanceTracker
  module Form
    TRANSACTION_TYPES = %w[income expense transfer].freeze

    CreateTransaction = Dry::Validation.Contract do
      params do
        required(:title).filled(:string, max_size?: 200)
        required(:transaction_type).filled(:string, included_in?: TRANSACTION_TYPES)
        required(:amount).filled(:string)
        required(:transaction_date).filled(:string)
        optional(:category_id).maybe(:string)
        optional(:note).maybe(:string)
        optional(:to_wallet_id).maybe(:string)
      end

      rule(:amount) do
        parsed = Float(value.to_s.strip, exception: false)
        if parsed.nil?
          key.failure('must be a valid number')
        elsif parsed <= 0
          key.failure('must be greater than zero')
        end
      end

      rule(:transaction_date) do
        Date.parse(value.to_s)
      rescue ArgumentError
        key.failure('must be a valid date')
      end

      rule(:to_wallet_id) do
        key.failure('is required for transfers') if values[:transaction_type] == 'transfer' && value.to_s.strip.empty?
      end
    end

    # Edit form — income/expense only; account cannot be changed after creation
    UpdateTransaction = Dry::Validation.Contract do
      params do
        required(:title).filled(:string, max_size?: 200)
        required(:transaction_type).filled(:string, included_in?: %w[income expense])
        required(:amount).filled(:string)
        required(:transaction_date).filled(:string)
        optional(:category_id).maybe(:string)
        optional(:note).maybe(:string)
      end

      rule(:amount) do
        parsed = Float(value.to_s.strip, exception: false)
        if parsed.nil?
          key.failure('must be a valid number')
        elsif parsed <= 0
          key.failure('must be greater than zero')
        end
      end

      rule(:transaction_date) do
        Date.parse(value.to_s)
      rescue ArgumentError
        key.failure('must be a valid date')
      end
    end
  end
end
