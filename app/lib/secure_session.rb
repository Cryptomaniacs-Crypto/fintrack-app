# frozen_string_literal: true

require 'json'
require_relative 'secure_message'

module FinanceTracker
  # Secure wrappers around rack session values.
  class SecureSession
    class << self
      def set(session, key, value)
        session[key.to_s] = SecureMessage.encrypt(JSON.generate(value))
        value
      end

      def get(session, key)
        ciphertext = session[key.to_s]
        return nil unless ciphertext

        JSON.parse(SecureMessage.decrypt(ciphertext))
      end

      def delete(session, key)
        session.delete(key.to_s)
      end
    end
  end
end
