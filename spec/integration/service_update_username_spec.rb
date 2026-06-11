# frozen_string_literal: true

require_relative '../spec_helper'
require 'webmock/minitest'

describe 'UpdateUsername service' do
  after { WebMock.reset! }

  it 'HAPPY: PUTs the new username with the bearer token and returns the account' do
    stub = WebMock.stub_request(:put, "#{API_URL}/api/v1/accounts/oldname")
                  .with(body: { username: 'new.name' }.to_json,
                        headers: { 'Authorization' => 'Bearer tok-123' })
                  .to_return(status: 200,
                             body: { data: { attributes: { username: 'new.name' } } }.to_json,
                             headers: { 'content-type' => 'application/json' })

    result = FinanceTracker::Services::UpdateUsername.new.call(
      current_username: 'oldname', new_username: 'new.name', auth_token: 'tok-123'
    )

    _(result['data']['attributes']['username']).must_equal 'new.name'
    assert_requested(stub)
  end

  it 'BAD: raises UsernameTaken on 409' do
    WebMock.stub_request(:put, "#{API_URL}/api/v1/accounts/oldname")
           .to_return(status: 409, body: { message: 'Username already taken' }.to_json,
                      headers: { 'content-type' => 'application/json' })

    _(proc {
      FinanceTracker::Services::UpdateUsername.new.call(current_username: 'oldname', new_username: 'taken', auth_token: 't')
    }).must_raise FinanceTracker::Services::UpdateUsername::UsernameTaken
  end

  it 'BAD: raises InvalidUsername on 400' do
    WebMock.stub_request(:put, "#{API_URL}/api/v1/accounts/oldname")
           .to_return(status: 400, body: { message: 'too short' }.to_json,
                      headers: { 'content-type' => 'application/json' })

    _(proc {
      FinanceTracker::Services::UpdateUsername.new.call(current_username: 'oldname', new_username: 'ab', auth_token: 't')
    }).must_raise FinanceTracker::Services::UpdateUsername::InvalidUsername
  end

  it 'SECURITY: raises UpdateError on 403' do
    WebMock.stub_request(:put, "#{API_URL}/api/v1/accounts/oldname")
           .to_return(status: 403, body: { message: 'Not allowed' }.to_json,
                      headers: { 'content-type' => 'application/json' })

    _(proc {
      FinanceTracker::Services::UpdateUsername.new.call(current_username: 'oldname', new_username: 'x', auth_token: 't')
    }).must_raise FinanceTracker::Services::UpdateUsername::UpdateError
  end
end
