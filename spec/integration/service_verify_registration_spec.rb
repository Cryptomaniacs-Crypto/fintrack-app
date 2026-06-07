# frozen_string_literal: true

require_relative '../spec_helper'
require 'webmock/minitest'

describe 'VerifyRegistration service' do
  before do
    ENV['MSG_KEY'] ||= FinanceTracker::SecureMessage.generate_key
    FinanceTracker::SecureMessage.setup(ENV.fetch('MSG_KEY'))

    config_class = Struct.new(:APP_URL, :API_URL)
    @config = config_class.new('https://app.example.com', API_URL)
    @registration = { email: 'newperson@example.com', username: 'newperson' }
  end

  after { WebMock.reset! }

  it 'HAPPY: posts the registration + verification_url to the API and returns the data' do
    WebMock.stub_request(:post, "#{API_URL}/api/v1/auth/register")
           .to_return(status: 202, body: { message: 'Verification email sent' }.to_json,
                      headers: { 'content-type' => 'application/json' })

    result = FinanceTracker::Services::VerifyRegistration.new(@config).call(**@registration)

    _(result[:email]).must_equal @registration[:email]
    assert_requested(:post, "#{API_URL}/api/v1/auth/register") do |req|
      # Body is now a signed envelope: the registration fields live under `data`.
      body = JSON.parse(req.body)['data']
      body['verification_url'].start_with?("#{@config.APP_URL}/auth/register/")
    end
  end

  it 'SECURITY: verification_url carries an encrypted token with the registration data' do
    decrypted = nil
    WebMock.stub_request(:post, "#{API_URL}/api/v1/auth/register").to_return(status: 202).with do |req|
      body = JSON.parse(req.body)['data']
      token = body['verification_url'].split('/').last
      decrypted = JSON.parse(FinanceTracker::SecureMessage.decrypt(token))
      true
    end

    FinanceTracker::Services::VerifyRegistration.new(@config).call(**@registration)

    _(decrypted).wont_be_nil
    _(decrypted['email']).must_equal @registration[:email]
    _(decrypted['username']).must_equal @registration[:username]
  end

  it 'BAD: raises VerificationError on 400 from API' do
    WebMock.stub_request(:post, "#{API_URL}/api/v1/auth/register")
           .to_return(status: 400, body: { message: 'Email already registered' }.to_json,
                      headers: { 'content-type' => 'application/json' })

    _(proc {
      FinanceTracker::Services::VerifyRegistration.new(@config).call(**@registration)
    }).must_raise FinanceTracker::Services::VerifyRegistration::VerificationError
  end

  it 'BAD: raises ApiServerError on 500' do
    WebMock.stub_request(:post, "#{API_URL}/api/v1/auth/register")
           .to_return(status: 500, body: { message: 'boom' }.to_json,
                      headers: { 'content-type' => 'application/json' })

    _(proc {
      FinanceTracker::Services::VerifyRegistration.new(@config).call(**@registration)
    }).must_raise FinanceTracker::Services::VerifyRegistration::ApiServerError
  end
end
