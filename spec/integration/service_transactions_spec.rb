# frozen_string_literal: true

require_relative '../spec_helper'
require 'webmock/minitest'

TXN_ID = '42'
TXN_ATTRS = {
  'id'               => TXN_ID,
  'title'            => 'Lunch',
  'amount'           => '-12.5',
  'transaction_date' => '2026-06-01',
  'note'             => '',
  'wallet_id'        => '1',
  'wallet_name'      => 'Cash',
  'category_id'      => nil,
  'category_name'    => nil
}.freeze

TXN_ENVELOPE = {
  'data' => {
    'type'       => 'transaction',
    'attributes' => TXN_ATTRS
  }
}.freeze

TXN_LIST_ENVELOPE = {
  'data' => [TXN_ENVELOPE]
}.freeze

describe 'GetTransaction service' do
  before { @auth = 'tok-abc' }
  after  { WebMock.reset! }

  it 'returns a Transaction for a valid id' do
    stub_request(:get, "#{API_URL}/api/v1/transactions/#{TXN_ID}")
      .to_return(status: 200, body: TXN_ENVELOPE.to_json, headers: { 'content-type' => 'application/json' })

    result = FinanceTracker::Services::GetTransaction.new.call(transaction_id: TXN_ID, auth_token: @auth)
    _(result).wont_be_nil
    _(result.title).must_equal 'Lunch'
    _(result.wallet_name).must_equal 'Cash'
  end

  it 'raises NotFoundError on 404' do
    stub_request(:get, "#{API_URL}/api/v1/transactions/#{TXN_ID}")
      .to_return(status: 404, body: { message: 'not found' }.to_json,
                 headers: { 'content-type' => 'application/json' })

    assert_raises(FinanceTracker::Services::GetTransaction::NotFoundError) do
      FinanceTracker::Services::GetTransaction.new.call(transaction_id: TXN_ID, auth_token: @auth)
    end
  end
end

describe 'UpdateTransaction service' do
  before { @auth = 'tok-abc' }
  after  { WebMock.reset! }

  it 'sends PATCH with signed amount for expense' do
    req = stub_request(:patch, "#{API_URL}/api/v1/transactions/#{TXN_ID}")
            .with(body: hash_including('amount' => '-12.5'))
            .to_return(status: 200, body: TXN_ENVELOPE.to_json, headers: { 'content-type' => 'application/json' })

    FinanceTracker::Services::UpdateTransaction.new.call(
      auth_token: @auth, transaction_id: TXN_ID,
      title: 'Lunch', transaction_type: 'expense', amount: '12.5',
      transaction_date: '2026-06-01'
    )
    assert_requested req
  end

  it 'sends positive amount for income' do
    req = stub_request(:patch, "#{API_URL}/api/v1/transactions/#{TXN_ID}")
            .with(body: hash_including('amount' => '500.0'))
            .to_return(status: 200, body: TXN_ENVELOPE.to_json, headers: { 'content-type' => 'application/json' })

    FinanceTracker::Services::UpdateTransaction.new.call(
      auth_token: @auth, transaction_id: TXN_ID,
      title: 'Salary', transaction_type: 'income', amount: '500',
      transaction_date: '2026-06-01'
    )
    assert_requested req
  end

  it 'raises InvalidInput when amount is zero' do
    assert_raises(FinanceTracker::Services::UpdateTransaction::InvalidInput) do
      FinanceTracker::Services::UpdateTransaction.new.call(
        auth_token: @auth, transaction_id: TXN_ID,
        title: 'x', transaction_type: 'expense', amount: '0',
        transaction_date: '2026-06-01'
      )
    end
  end
end

describe 'DeleteTransaction service' do
  before { @auth = 'tok-abc' }
  after  { WebMock.reset! }

  it 'sends DELETE to the API' do
    req = stub_request(:delete, "#{API_URL}/api/v1/transactions/#{TXN_ID}")
            .to_return(status: 204, body: '')

    FinanceTracker::Services::DeleteTransaction.new.call(transaction_id: TXN_ID, auth_token: @auth)
    assert_requested req
  end

  it 'raises NotFoundError on 404' do
    stub_request(:delete, "#{API_URL}/api/v1/transactions/#{TXN_ID}")
      .to_return(status: 404, body: { message: 'not found' }.to_json,
                 headers: { 'content-type' => 'application/json' })

    assert_raises(FinanceTracker::Services::DeleteTransaction::NotFoundError) do
      FinanceTracker::Services::DeleteTransaction.new.call(transaction_id: TXN_ID, auth_token: @auth)
    end
  end
end

describe 'ListTransactions service' do
  before { @auth = 'tok-abc' }
  after  { WebMock.reset! }

  it 'returns an array of Transaction objects' do
    stub_request(:get, "#{API_URL}/api/v1/transactions")
      .to_return(status: 200, body: TXN_LIST_ENVELOPE.to_json,
                 headers: { 'content-type' => 'application/json' })

    result = FinanceTracker::Services::ListTransactions.new.call(auth_token: @auth)
    _(result).must_be_kind_of Array
    _(result.first.title).must_equal 'Lunch'
  end

  it 'filters by wallet_id when provided' do
    req = stub_request(:get, "#{API_URL}/api/v1/transactions?wallet_id=1")
            .to_return(status: 200, body: TXN_LIST_ENVELOPE.to_json,
                       headers: { 'content-type' => 'application/json' })

    FinanceTracker::Services::ListTransactions.new.call(auth_token: @auth, wallet_id: '1')
    assert_requested req
  end
end
