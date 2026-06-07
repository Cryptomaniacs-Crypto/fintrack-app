# frozen_string_literal: true

require_relative '../spec_helper'
require 'base64'
require 'rbnacl'

describe 'SignedMessage' do
  before do
    # Each example signs with a fresh throwaway keypair; the matching public
    # verify key plays the role of the API's VERIFY_KEY.
    @signing_key = RbNaCl::SigningKey.generate
    FinanceTracker::SignedMessage.setup(Base64.strict_encode64(@signing_key.to_bytes))
  end

  it 'BAD: should raise KeypairError when setup with a bad signing key' do
    _(proc { FinanceTracker::SignedMessage.setup(nil) })
      .must_raise FinanceTracker::SignedMessage::KeypairError
    _(proc { FinanceTracker::SignedMessage.setup('') })
      .must_raise FinanceTracker::SignedMessage::KeypairError
    _(proc { FinanceTracker::SignedMessage.setup('not-a-base64-key!') })
      .must_raise FinanceTracker::SignedMessage::KeypairError
  end

  it 'HAPPY: should sign a message that the matching verify key accepts' do
    message = { username: 'new_user', email: 'new@example.com' }

    signed = FinanceTracker::SignedMessage.sign(message)

    _(signed[:data]).must_equal message
    signature = Base64.strict_decode64(signed[:signature])
    verified = @signing_key.verify_key.verify(signature, message.to_json)
    _(verified).must_equal true
  end

  it 'SECURITY: signature should not verify a tampered message' do
    signed = FinanceTracker::SignedMessage.sign({ username: 'new_user' })
    tampered = { username: 'attacker' }.to_json

    signature = Base64.strict_decode64(signed[:signature])
    _(proc { @signing_key.verify_key.verify(signature, tampered) })
      .must_raise RbNaCl::BadSignatureError
  end

  it 'HAPPY: signing should be deterministic (same message, same signature)' do
    # Ed25519 is deterministic, so WebMock body stubs can pre-compute the
    # exact signed body a service will send.
    message = { username: 'new_user', password: 'pa55w0rd' }

    _(FinanceTracker::SignedMessage.sign(message))
      .must_equal FinanceTracker::SignedMessage.sign(message)
  end

  it 'BAD: should raise KeypairError when signing before setup' do
    FinanceTracker::SignedMessage.instance_variable_set(:@signing_key, nil)

    _(proc { FinanceTracker::SignedMessage.sign({ a: 1 }) })
      .must_raise FinanceTracker::SignedMessage::KeypairError
  end
end
