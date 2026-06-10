# frozen_string_literal: true

require 'dry-validation'
require_relative 'form_base'

module FinanceTracker
  module Form
    UpdatePaymentMethod = Dry::Validation.Contract do
      params do
        required(:name).filled(:string, max_size?: 200)
        optional(:account_number).maybe(:string, max_size?: 100)
      end
    end
  end
end
