# frozen_string_literal: true

require_relative '../spec_helper'

describe 'RegistrationToken' do
  before do
    ENV['MSG_KEY'] ||= FinanceTracker::SecureMessage.generate_key
    FinanceTracker::SecureMessage.setup(ENV.fetch('MSG_KEY'))
  end

  it 'HAPPY: round-trips email and username' do
    token = FinanceTracker::RegistrationToken.new(
      email: 'new.user@example.com',
      username: 'new_user'
    ).to_s

    loaded = FinanceTracker::RegistrationToken.load(token)

    _(loaded.email).must_equal 'new.user@example.com'
    _(loaded.username).must_equal 'new_user'
  end

  it 'SAD: rejects tampered tokens' do
    token = FinanceTracker::RegistrationToken.new(
      email: 'new.user@example.com',
      username: 'new_user'
    ).to_s
    tampered = token.dup
    tampered[0] = tampered[0] == 'a' ? 'b' : 'a'

    _ { FinanceTracker::RegistrationToken.load(tampered) }
      .must_raise FinanceTracker::RegistrationToken::InvalidTokenError
  end
end
