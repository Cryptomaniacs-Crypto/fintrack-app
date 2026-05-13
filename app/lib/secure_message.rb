# frozen_string_literal: true

require 'base64'
require 'rbnacl'

module FinanceTracker
  # Encrypt and decrypt message payloads with NaCl SimpleBox.
  class SecureMessage
    class NoMsgKeyError < StandardError; end
    class KeyNotInitializedError < StandardError; end

    class << self
      attr_reader :key

      def setup(msg_key)
        raise NoMsgKeyError, 'MSG_KEY is required' if msg_key.to_s.strip.empty?

        decoded = Base64.strict_decode64(msg_key)
        unless decoded.bytesize == RbNaCl::SecretBox.key_bytes
          raise NoMsgKeyError, "MSG_KEY must decode to #{RbNaCl::SecretBox.key_bytes} bytes"
        end

        @key = decoded
      rescue ArgumentError
        raise NoMsgKeyError, 'MSG_KEY must be valid base64'
      end

      def generate_key
        key = RbNaCl::Random.random_bytes(RbNaCl::SecretBox.key_bytes)
        Base64.strict_encode64(key)
      end

      def encrypt(plaintext)
        raise ArgumentError, 'message missing' if plaintext.nil?

        simple_box = RbNaCl::SimpleBox.from_secret_key(key!)
        ciphertext = simple_box.encrypt(plaintext.to_s)
        Base64.urlsafe_encode64(ciphertext)
      end

      def decrypt(ciphertext64)
        raise ArgumentError, 'ciphertext missing' if ciphertext64.nil?

        ciphertext = Base64.urlsafe_decode64(ciphertext64)
        simple_box = RbNaCl::SimpleBox.from_secret_key(key!)
        simple_box.decrypt(ciphertext).force_encoding(Encoding::UTF_8)
      end

      private

      def key!
        raise KeyNotInitializedError, 'SecureMessage.setup must be called first' unless @key

        @key
      end
    end
  end
end
