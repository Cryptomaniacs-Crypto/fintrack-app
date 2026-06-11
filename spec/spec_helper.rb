# frozen_string_literal: true

ENV['RACK_ENV'] = 'test'

# Generate test MSG_KEY if not already set
unless ENV['MSG_KEY']
  require 'rbnacl'
  require 'base64'
  key = RbNaCl::Random.random_bytes(RbNaCl::SecretBox.key_bytes)
  ENV['MSG_KEY'] = Base64.strict_encode64(key)
end

# Generate a throwaway SIGNING_KEY for the test run if not already set, so
# SignedMessage.setup succeeds at boot and specs can sign request bodies.
unless ENV['SIGNING_KEY']
  require 'rbnacl'
  require 'base64'
  ENV['SIGNING_KEY'] = Base64.strict_encode64(RbNaCl::SigningKey.generate.to_bytes)
end

require 'minitest/autorun'
require 'minitest/spec'
require 'minitest/rg'
require_relative 'test_load_all'

API_URL = ENV.fetch('FINTRACK_API_URL', 'http://localhost:9292')

# Wrap a request body the way the signing services do, so WebMock body
# matchers can pre-compute the exact payload (Ed25519 signing is deterministic).
def signed_body(body)
  FinanceTracker::SignedMessage.sign(body).to_json
end