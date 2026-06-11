# frozen_string_literal: true

require 'dry-validation'
require_relative 'form_base'

module FinanceTracker
  module Form
    # Same handle rules as registration: 4-50 chars, ASCII letters/digits/dots/underscores.
    ChangeUsername = Dry::Validation.Contract do
      params do
        required(:username).filled(:string, min_size?: 4, max_size?: 50)
      end

      rule(:username) do
        unless USERNAME_REGEX.match?(value)
          key.failure('must contain only ASCII letters, digits, dots, or underscores')
        end
      end
    end
  end
end
