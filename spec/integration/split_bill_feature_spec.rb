# frozen_string_literal: true

require_relative '../spec_helper'
require 'webmock/minitest'

describe 'Split bill feature' do
  include Rack::Test::Methods

  before do
    clear_cookies
  end

  after do
    WebMock.reset!
  end

  # Establish a real logged-in session by driving the actual POST /auth/login
  # route with the API authenticate call stubbed. This is how production sets
  # the encrypted `current_account` value inside Roda's signed session cookie,
  # which Rack::Test then resends on subsequent requests in the same test.
  def login_as(username: 'tester', roles: ['member'])
    api_response = {
      'data' => {
        'attributes' => {
          'username' => username,
          'email' => "#{username}@example.com",
          'auth_token' => 'test-token-123'
        }
      },
      'included' => { 'system_roles' => roles }
    }

    WebMock.stub_request(:post, "#{API_URL}/api/v1/auth/authentication")
      .to_return(
        body: api_response.to_json,
        headers: { 'content-type' => 'application/json' }
      )

    post '/auth/login', { username: username, password: 'mypa$$w0rd' }
  end

  it 'redirects guests to login page' do
    get '/split-bill'

    _(last_response.status).must_equal 302
    _(last_response.headers['Location']).must_equal '/auth/login'
  end

  it 'shows split result for logged in user' do
    login_as

    post '/split-bill', {
      tax_percent: '10',
      service_percent: '5',
      participants: [
        { 'name' => 'Alice', 'amount' => '100' },
        { 'name' => 'Bob', 'amount' => '200' }
      ]
    }

    _(last_response.status).must_equal 200
    _(last_response.body).must_include 'Result'
    _(last_response.body).must_include '$115.0'
    _(last_response.body).must_include '$230.0'
    _(last_response.body).must_include '$345.0'
  end

  it 'shows validation error for missing amount' do
    login_as

    post '/split-bill', {
      participants: [
        { 'name' => 'Alice', 'amount' => '' }
      ]
    }

    _(last_response.status).must_equal 200
    _(last_response.body).must_include 'Amount for Alice is required'
  end
end
