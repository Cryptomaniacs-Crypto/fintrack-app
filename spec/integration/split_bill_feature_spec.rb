# frozen_string_literal: true

require_relative '../spec_helper'

describe 'Split bill feature' do
  include Rack::Test::Methods

  before do
    clear_cookies
  end

  it 'redirects guests to login page' do
    get '/split-bill'

    _(last_response.status).must_equal 302
    _(last_response.headers['Location']).must_equal '/auth/login'
  end

  it 'shows split result for logged in user' do
    user = { 'username' => 'tester', 'system_roles' => ['member'] }
    session_data = FinanceTracker::SecureSession::Encryptor.new(App.config.MSG_KEY).encrypt(user)

    rack_mock_session.cookie_jar['current_account'] = session_data

    post '/split-bill', {
      subtotal: '100',
      tax: '10',
      tip: '10',
      participants: "Alice\nBob"
    }

    _(last_response.status).must_equal 200
    _(last_response.body).must_include 'Result'
    _(last_response.body).must_include '$60.0'
  end

  it 'shows validation error for invalid participants' do
    user = { 'username' => 'tester', 'system_roles' => ['member'] }
    session_data = FinanceTracker::SecureSession::Encryptor.new(App.config.MSG_KEY).encrypt(user)

    rack_mock_session.cookie_jar['current_account'] = session_data

    post '/split-bill', {
      subtotal: '100',
      participants: 'Alice'
    }

    _(last_response.status).must_equal 200
    _(last_response.body).must_include 'At least two participants are required'
  end
end