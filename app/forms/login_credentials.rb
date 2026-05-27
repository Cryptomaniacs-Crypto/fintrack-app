# frozen_string_literal: true

require 'dry-validation'
require_relative 'form_base'

module FinanceTracker
  module Form
    # Login: username + password presence only. Format/strength rules
    # belong to Registration; login simply asks "did the user fill both
    # fields?" before forwarding to the API.
    LoginCredentials = Dry::Validation.Contract do
      params do
        required(:username).filled(:string)
        required(:password).filled(:string)
      end
    end
  end
end
