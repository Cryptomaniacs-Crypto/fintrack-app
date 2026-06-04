# frozen_string_literal: true

ENV['RACK_ENV'] = 'test'

# Generate test MSG_KEY if not already set
unless ENV['MSG_KEY']
  require 'rbnacl'
  require 'base64'
  key = RbNaCl::Random.random_bytes(RbNaCl::SecretBox.key_bytes)
  ENV['MSG_KEY'] = Base64.strict_encode64(key)
end

require 'minitest/autorun'
require 'minitest/spec'
require 'minitest/rg'
require_relative 'test_load_all'

API_URL = ENV.fetch('FINTRACK_API_URL', 'http://localhost:9292')