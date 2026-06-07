# frozen_string_literal: true

require_relative '../spec_helper'
require 'webmock/minitest'

describe 'Test Service Objects' do
  before do
    @credentials = {
      username: 'testuser',
      password: 'mypa$$w0rd'
    }

    @bad_credentials = {
      username: 'testuser',
      password: 'wrongpassword'
    }

    @api_response = {
      'data' => {
        'attributes' => {
          'username' => 'testuser',
          'email' => 'test@example.com',
          'auth_token' => 'test-token-123'
        }
      },
      'included' => {
        'system_roles' => []
      }
    }
  end

  after do
    WebMock.reset!
  end

  describe 'Authenticate account' do
    it 'HAPPY: should authenticate with valid credentials' do
      WebMock.stub_request(:post, "#{API_URL}/api/v1/auth/authentication")
        .with(body: signed_body(@credentials))
        .to_return(
          body: @api_response.to_json,
          headers: { 'content-type' => 'application/json' }
        )

      result = FinanceTracker::Services::AuthenticateAccount.new.call(**@credentials)
      _(result).wont_be_nil
      _(result[:account]['username']).must_equal 'testuser'
      _(result[:account]['email']).must_equal 'test@example.com'
      _(result[:auth_token]).must_equal 'test-token-123'
    end

    it 'BAD: should raise error on wrong credentials' do
      WebMock.stub_request(:post, "#{API_URL}/api/v1/auth/authentication")
        .with(body: signed_body(@bad_credentials))
        .to_return(status: 403)

      assert_raises FinanceTracker::Services::AuthenticateAccount::UnauthorizedError do
        FinanceTracker::Services::AuthenticateAccount.new.call(**@bad_credentials)
      end
    end
  end
end