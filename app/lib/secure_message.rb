# frozen_string_literal: true

require 'base64'
require 'rbnacl'

module FinanceTracker
  # Encrypt and decrypt message payloads with NaCl SimpleBox.
  class SecureMessage
    class NoMsgKeyError < StandardError; end

    class << self
      def setup(msg_key)
        raise NoMsgKeyError unless msg_key

        @key = Base64.strict_decode64(msg_key)
      end

      def generate_key
        key = RbNaCl::Random.random_bytes(RbNaCl::SecretBox.key_bytes)
        Base64.strict_encode64(key)
      end

      def encrypt(plaintext)
        return nil unless plaintext

        simple_box = RbNaCl::SimpleBox.from_secret_key(@key)
        ciphertext = simple_box.encrypt(plaintext.to_s)
        Base64.strict_encode64(ciphertext)
      end

      def decrypt(ciphertext64)
        return nil unless ciphertext64

        ciphertext = Base64.strict_decode64(ciphertext64)
        simple_box = RbNaCl::SimpleBox.from_secret_key(@key)
        simple_box.decrypt(ciphertext).force_encoding(Encoding::UTF_8)
      end
    end
  end
end
