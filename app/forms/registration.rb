# frozen_string_literal: true

require 'dry-validation'
require_relative 'form_base'

module FinanceTracker
  module Form
    # Registration: username regex + email shape + minimum password length.
    Registration = Dry::Validation.Contract do
      params do
        required(:username).filled(:string, min_size?: 4, max_size?: 50)
        required(:email).filled(:string, max_size?: 254)
        required(:password).filled(:string, min_size?: 8)
      end

      rule(:username) do
        unless USERNAME_REGEX.match?(value)
          key.failure('must contain only ASCII letters, digits, dots, or underscores')
        end
      end

      rule(:email) do
        key.failure('must contain an @ sign') unless EMAIL_REGEX.match?(value)
      end
    end
  end
end
