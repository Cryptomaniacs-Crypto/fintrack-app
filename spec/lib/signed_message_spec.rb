# frozen_string_literal: true

require_relative '../spec_helper'

describe 'SignedMessage' do
  # Snapshot/restore the class-level key so other specs that rely on the
  # test SIGNING_KEY from secrets.yml are not disrupted by this spec file.
  before do
    @saved_key = FinanceTracker::SignedMessage.instance_variable_get(:@signing_key)
    @signing_key = RbNaCl::SigningKey.generate
    FinanceTracker::SignedMessage.setup(Base64.strict_encode64(@signing_key.to_bytes))
  end

  after do
    FinanceTracker::SignedMessage.instance_variable_set(:@signing_key, @saved_key)
  end

  it 'BAD: should raise KeypairError when setup with a bad signing key' do
    _(proc { FinanceTracker::SignedMessage.setup(nil) })
      .must_raise FinanceTracker::SignedMessage::KeypairError
    _(proc { FinanceTracker::SignedMessage.setup('not-a-base64-key!') })
      .must_raise FinanceTracker::SignedMessage::KeypairError
  end

  it 'HAPPY: should sign a message that the verify key can verify' do
    message = { username: 'new_user', email: 'new@example.com' }

    signed = FinanceTracker::SignedMessage.sign(message)

    _(signed[:data]).must_equal message
    signature = Base64.strict_decode64(signed[:signature])
    verified = @signing_key.verify_key.verify(signature, signed[:data].to_json)
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
    # Ed25519 is deterministic — WebMock body stubs can pre-compute the exact
    # signed body a service will send without needing to mock the signing step.
    message = { username: 'new_user', password: 'pa55w0rd' }

    _(FinanceTracker::SignedMessage.sign(message)).must_equal FinanceTracker::SignedMessage.sign(message)
  end
end
