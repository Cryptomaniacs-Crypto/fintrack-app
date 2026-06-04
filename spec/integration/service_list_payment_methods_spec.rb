# frozen_string_literal: true

require_relative '../spec_helper'
require 'webmock/minitest'

describe 'ListPaymentMethods service' do
  before do
    @auth_token = 'auth-123'
    @acct_token = 'acct-456'
    @api_response = { 'data' => [{ 'id' => '1', 'attributes' => { 'name' => 'Cash' } }] }
  end

  after { WebMock.reset! }

  it 'sends Account-Api-Token header when provided' do
    request = WebMock.stub_request(:get, "#{API_URL}/api/v1/wallets")
                     .with(headers: { 'Account-Api-Token' => @acct_token, 'Authorization' => "Bearer #{@auth_token}" })
                     .to_return(status: 200, body: @api_response.to_json, headers: { 'content-type' => 'application/json' })

    result = FinanceTracker::Services::ListPaymentMethods.new.call(auth_token: @auth_token, account_api_token: @acct_token)

    assert_requested request
    _(result).wont_be_nil
  end
end
