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
          'email' => 'test@example.com'
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
        .with(body: @credentials.to_json)
        .to_return(
          body: @api_response.to_json,
          headers: { 'content-type' => 'application/json' }
        )

      account = FinanceTracker::Services::AuthenticateAccount.new.call(**@credentials)
      _(account).wont_be_nil
      _(account['username']).must_equal 'testuser'
      _(account['email']).must_equal 'test@example.com'
    end

    it 'BAD: should raise error on wrong credentials' do
      WebMock.stub_request(:post, "#{API_URL}/api/v1/auth/authentication")
        .with(body: @bad_credentials.to_json)
        .to_return(status: 403)

      assert_raises FinanceTracker::Services::AuthenticateAccount::UnauthorizedError do
        FinanceTracker::Services::AuthenticateAccount.new.call(**@bad_credentials)
      end
    end
  end
end