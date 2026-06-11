# frozen_string_literal: true

require_relative '../spec_helper'

describe 'SSO CSRF state check' do
  it 'HAPPY: callback with no session state redirects to login (expired nonce)' do
    # No prior GET /auth/login → no sso_state in session → treat as expired
    get '/auth/sso_callback?state=any-state&code=any-code'

    _(last_response.status).must_equal 302
    _(last_response.headers['Location']).must_include '/auth/login'
  end

  it 'SECURITY: callback with mismatched state redirects to login (CSRF attempt)' do
    # Seed a real nonce by visiting the login page
    get '/auth/login'
    # Attacker forges a different state value — must be rejected
    get '/auth/sso_callback?state=tampered_state&code=any-code'

    _(last_response.status).must_equal 302
    _(last_response.headers['Location']).must_include '/auth/login'
  end
end
