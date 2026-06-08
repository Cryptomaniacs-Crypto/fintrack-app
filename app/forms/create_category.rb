# frozen_string_literal: true

require 'dry-validation'
require_relative 'form_base'

module FinanceTracker
  module Form
    CreateCategory = Dry::Validation.Contract do
      params do
        required(:name).filled(:string, max_size?: 100)
      end
    end
  end
end
