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

  it 'redirects guests to agreements page login' do
    get '/split-bill/agreements'

    _(last_response.status).must_equal 302
    _(last_response.headers['Location']).must_equal '/auth/login'
  end

  it 'shows split result for logged in user' do
    user = { 'username' => 'tester', 'system_roles' => ['member'] }
    session_data = FinanceTracker::SecureMessage.encrypt(user.to_json)
    auth_env = { 'rack.session' => { 'current_account' => session_data } }

    post '/split-bill', {
      tax_percent: '10',
      service_percent: '5',
      participants: [
        { 'name' => 'Alice', 'amount' => '100' },
        { 'name' => 'Bob', 'amount' => '200' }
      ]
    }, auth_env

    _(last_response.status).must_equal 200
    _(last_response.body).must_include 'Result'
    _(last_response.body).must_include '/js/split_bill.js'
    _(last_response.body).must_include '/split-bill/agreements'
    _(last_response.body).must_include '$115.0'
    _(last_response.body).must_include '$230.0'
    _(last_response.body).must_include '$345.0'
  end

  it 'shows agreements page for logged in user' do
    user = { 'username' => 'tester', 'system_roles' => ['member'] }
    session_data = FinanceTracker::SecureMessage.encrypt(user.to_json)
    auth_env = { 'rack.session' => { 'current_account' => session_data } }

    get '/split-bill/agreements', {}, auth_env

    _(last_response.status).must_equal 200
    _(last_response.body).must_include 'My Agreements'
  end

  it 'shows validation error for missing amount' do
    user = { 'username' => 'tester', 'system_roles' => ['member'] }
    session_data = FinanceTracker::SecureMessage.encrypt(user.to_json)
    auth_env = { 'rack.session' => { 'current_account' => session_data } }

    post '/split-bill', {
      participants: [
        { 'name' => 'Alice', 'amount' => '' }
      ]
    }, auth_env

    _(last_response.status).must_equal 200
    _(last_response.body).must_include 'Amount for Alice is required'
  end

end