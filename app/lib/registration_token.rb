# frozen_string_literal: true

require 'json'
require_relative 'secure_message'

module FinanceTracker
  # Wraps registration payloads in a SecureMessage token.
  class RegistrationToken
    class InvalidTokenError < StandardError; end

    def self.load(token_string)
      payload = JSON.parse(SecureMessage.decrypt(token_string))
      new(
        email: payload.fetch('email'),
        username: payload.fetch('username'),
        token: token_string
      )
    rescue StandardError
      raise InvalidTokenError, 'Invalid or tampered registration token'
    end

    attr_reader :email, :username

    def initialize(email:, username:, token: nil)
      @email = email
      @username = username
      @token = token || SecureMessage.encrypt(JSON.generate(email: email, username: username))
    end

    def to_s
      @token
    end
  end
end
