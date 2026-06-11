# frozen_string_literal: true

require 'dry-validation'
require_relative '../lib/string_security'

module FinanceTracker
  # Shared form-validation helpers and constants for FinanceTracker.
  # Individual contracts live in sibling files under app/forms/.
  module Form
    # ASCII-only username: rejects unicode confusables (e.g. Cyrillic А).
    USERNAME_REGEX = /\A[a-zA-Z0-9]+([._]?[a-zA-Z0-9]+)*\z/

    # Simplest "looks-like-an-email" check; deep correctness is verified
    # via the API verification flow, not a regex.
    EMAIL_REGEX = /@/

    # Minimum Shannon entropy for a password.
    # "aaaaaaaa" ≈ 0.0 fails; a mixed-character password passes at ~3.4+.
    PASSWORD_ENTROPY_MIN = 3.0

    # Flattens dry-validation errors to a single string per field.
    # Returns a Hash like { username: 'must be filled', password: '...' }.
    def self.validation_errors(validation)
      validation.errors.to_h.transform_values(&:first)
    end

    # Original (sanitized) input values, for re-rendering the form.
    def self.message_values(validation)
      validation.values.to_h
    end
  end
end
