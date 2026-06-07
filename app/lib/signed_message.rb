# frozen_string_literal: true

require 'base64'
require 'json'
require 'rbnacl'

module FinanceTracker
  # Signs outgoing API request bodies with the App's private Ed25519
  # SIGNING_KEY so the API -- holding only the matching public VERIFY_KEY --
  # can confirm that requests which carry no auth_token (login, register,
  # SSO) really came from this app and were not tampered with in transit.
  #
  # Signed body shape sent to the API:  { data: <message>, signature: <b64> }
  # The signature is computed over `message.to_json`, the exact bytes the API
  # re-serializes and checks with SignedRequest.verify.
  class SignedMessage
    class KeypairError < StandardError; end

    class << self
      # Call once at boot with the base64-encoded private signing key.
      def setup(signing_key64)
        raise KeypairError, 'SIGNING_KEY is required' if signing_key64.to_s.strip.empty?

        @signing_key = Base64.strict_decode64(signing_key64)
      rescue ArgumentError
        raise KeypairError, 'SIGNING_KEY must be valid base64'
      end

      # Generate an Ed25519 keypair. The private `signing_key` half becomes
      # this app's SIGNING_KEY; the public `verify_key` half goes to the API's
      # VERIFY_KEY. The API never receives the signing half, so it can verify
      # but can never forge a signed request (non-repudiation).
      def generate_keypair
        signing_key = RbNaCl::SigningKey.generate
        {
          signing_key: Base64.strict_encode64(signing_key.to_bytes),
          verify_key: Base64.strict_encode64(signing_key.verify_key.to_bytes)
        }
      end

      def sign(message)
        signature = RbNaCl::SigningKey.new(signing_key!)
          .sign(message.to_json)
          .then { |sig| Base64.strict_encode64(sig) }

        { data: message, signature: signature }
      end

      private

      def signing_key!
        raise KeypairError, 'SignedMessage.setup must be called first' unless @signing_key

        @signing_key
      end
    end
  end
end
