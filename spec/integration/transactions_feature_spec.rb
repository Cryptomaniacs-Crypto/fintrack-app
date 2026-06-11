# frozen_string_literal: true

require_relative '../spec_helper'
require 'webmock/minitest'

# App.config.API_URL ends with /api/v1 (e.g. http://localhost:3000/api/v1).
# ApiClient strips the /api/v1 prefix from paths when base_url already ends with it,
# so the final URL it calls is base_url + "/transactions" etc.
FEAT_API = begin
  raw = FinanceTracker::App.config.API_URL.to_s.chomp('/')
  raw.end_with?('/api/v1') ? raw : "#{raw}/api/v1"
end

FEAT_TXN_ID    = 'txn-99'
FEAT_WALLET_ID = 'wallet-1'

FEAT_TXN_ATTRS = {
  'id'               => FEAT_TXN_ID,
  'title'            => 'Coffee',
  'amount'           => '-4.5',
  'transaction_date' => '2026-06-07',
  'note'             => '',
  'wallet_id'        => FEAT_WALLET_ID,
  'wallet_name'      => 'Cash',
  'category_id'      => nil,
  'category_name'    => nil
}.freeze

FEAT_TXN_ENVELOPE = {
  'data' => { 'type' => 'transaction', 'attributes' => FEAT_TXN_ATTRS }
}.freeze

FEAT_WALLETS_ENVELOPE = {
  'data' => [
    { 'id' => FEAT_WALLET_ID, 'attributes' => {
      'name' => 'Cash', 'balance' => '100', 'method_type' => 'cash'
    } },
    { 'id' => 'wallet-2', 'attributes' => {
      'name' => 'LINE Pay', 'balance' => '50', 'method_type' => 'e_wallet'
    } }
  ]
}.freeze

FEAT_CATEGORIES_ENVELOPE = {
  'data' => [{ 'id' => '1', 'attributes' => { 'name' => 'Food', 'description' => '' } }]
}.freeze

FEAT_TXN_LIST_ENVELOPE = {
  'data' => [FEAT_TXN_ENVELOPE]
}.freeze

def stub_txn_list
  stub_request(:get, "#{FEAT_API}/transactions")
    .to_return(status: 200, body: FEAT_TXN_LIST_ENVELOPE.to_json,
               headers: { 'content-type' => 'application/json' })
end

def stub_txn_show(id = FEAT_TXN_ID)
  stub_request(:get, "#{FEAT_API}/transactions/#{id}")
    .to_return(status: 200, body: FEAT_TXN_ENVELOPE.to_json,
               headers: { 'content-type' => 'application/json' })
end

def stub_wallets
  stub_request(:get, "#{FEAT_API}/wallets")
    .to_return(status: 200, body: FEAT_WALLETS_ENVELOPE.to_json,
               headers: { 'content-type' => 'application/json' })
end

def stub_categories
  stub_request(:get, "#{FEAT_API}/categories")
    .to_return(status: 200, body: FEAT_CATEGORIES_ENVELOPE.to_json,
               headers: { 'content-type' => 'application/json' })
end

def stub_txn_create
  stub_request(:post, "#{FEAT_API}/transactions")
    .to_return(status: 201, body: { 'data' => FEAT_TXN_ATTRS }.to_json,
               headers: { 'content-type' => 'application/json' })
end

def stub_txn_update(id = FEAT_TXN_ID)
  stub_request(:patch, "#{FEAT_API}/transactions/#{id}")
    .to_return(status: 200, body: FEAT_TXN_ENVELOPE.to_json,
               headers: { 'content-type' => 'application/json' })
end

def stub_txn_delete(id = FEAT_TXN_ID)
  stub_request(:delete, "#{FEAT_API}/transactions/#{id}")
    .to_return(status: 204, body: '')
end

describe 'Transaction routes' do
  include Rack::Test::Methods

  before do
    clear_cookies
    user         = { 'username' => 'tester', 'system_roles' => ['member'] }
    session_data = FinanceTracker::SecureMessage.encrypt(user.to_json)
    @auth_env    = { 'rack.session' => { 'current_account' => session_data } }
  end

  after { WebMock.reset! }

  # ── Auth guards ──────────────────────────────────────────────────────────

  it 'redirects guests from GET /transactions to login' do
    get '/transactions'
    _(last_response.status).must_equal 302
    _(last_response.headers['Location']).must_equal '/auth/login'
  end

  it 'redirects guests from GET /transactions/new to login' do
    get '/transactions/new'
    _(last_response.status).must_equal 302
    _(last_response.headers['Location']).must_equal '/auth/login'
  end

  it 'redirects guests from GET /transactions/:id to login' do
    get "/transactions/#{FEAT_TXN_ID}"
    _(last_response.status).must_equal 302
    _(last_response.headers['Location']).must_equal '/auth/login'
  end

  it 'redirects guests from GET /transactions/:id/edit to login' do
    get "/transactions/#{FEAT_TXN_ID}/edit"
    _(last_response.status).must_equal 302
    _(last_response.headers['Location']).must_equal '/auth/login'
  end

  # ── GET /transactions ─────────────────────────────────────────────────────

  it 'shows My Transactions list for logged-in user' do
    stub_txn_list
    stub_wallets     # filter dropdown data
    stub_categories  # filter dropdown data
    get '/transactions', {}, @auth_env
    _(last_response.status).must_equal 200
    _(last_response.body).must_include 'My Transactions'
    _(last_response.body).must_include 'Coffee'
    _(last_response.body).must_include 'Cash'
  end

  it 'filters transactions by search query' do
    stub_txn_list
    stub_wallets
    stub_categories
    get '/transactions', { 'q' => 'nonexistent' }, @auth_env
    _(last_response.status).must_equal 200
    _(last_response.body).must_include 'No transactions match your filters'
  end

  it 'exports transactions as CSV' do
    stub_txn_list
    get '/transactions/export', {}, @auth_env
    _(last_response.status).must_equal 200
    _(last_response.headers['Content-Type']).must_include 'text/csv'
    _(last_response.headers['Content-Disposition']).must_include 'attachment'
    _(last_response.body).must_include 'Date,Description,Note,Wallet,Category,Type,Amount'
    _(last_response.body).must_include 'Coffee'
  end

  it 'shows empty state when no transactions' do
    stub_request(:get, "#{FEAT_API}/transactions")
      .to_return(status: 200, body: { 'data' => [] }.to_json,
                 headers: { 'content-type' => 'application/json' })
    stub_wallets
    stub_categories
    get '/transactions', {}, @auth_env
    _(last_response.status).must_equal 200
    _(last_response.body).must_include 'No transactions yet'
  end

  it 'shows flash error and empty list when API fails on /transactions' do
    stub_request(:get, "#{FEAT_API}/transactions")
      .to_return(status: 500, body: { message: 'server error' }.to_json,
                 headers: { 'content-type' => 'application/json' })
    get '/transactions', {}, @auth_env
    _(last_response.status).must_equal 200
    _(last_response.body).must_include 'Could not load transactions'
  end

  # ── GET /transactions/new ─────────────────────────────────────────────────

  it 'shows Record Transaction form with Transfer option' do
    stub_wallets
    stub_categories
    get '/transactions/new', {}, @auth_env
    _(last_response.status).must_equal 200
    _(last_response.body).must_include 'Record Transaction'
    _(last_response.body).must_include 'Cash'
    _(last_response.body).must_include 'Transfer'
  end

  it 'pre-selects wallet when ?wallet_id= is provided' do
    stub_wallets
    stub_categories
    get "/transactions/new?wallet_id=#{FEAT_WALLET_ID}", {}, @auth_env
    _(last_response.status).must_equal 200
    _(last_response.body).must_include "value=\"#{FEAT_WALLET_ID}\""
    _(last_response.body).must_include 'selected=""'
  end

  # ── POST /transactions (create) ───────────────────────────────────────────

  it 'creates income transaction and redirects to account page' do
    stub_txn_create
    post '/transactions', {
      wallet_id: FEAT_WALLET_ID, title: 'Salary',
      transaction_type: 'income', amount: '5000',
      transaction_date: '2026-06-07'
    }, @auth_env
    _(last_response.status).must_equal 302
    _(last_response.headers['Location']).must_include '/payment-methods/'
  end

  it 'shows validation error when wallet not selected' do
    stub_wallets
    stub_categories
    post '/transactions', {
      wallet_id: '', title: 'Lunch', transaction_type: 'expense',
      amount: '15', transaction_date: '2026-06-07'
    }, @auth_env
    _(last_response.status).must_equal 200
    _(last_response.body).must_include 'Please select a wallet'
  end

  it 'shows validation error when amount is invalid' do
    stub_wallets
    stub_categories
    post '/transactions', {
      wallet_id: FEAT_WALLET_ID, title: 'Lunch',
      transaction_type: 'expense', amount: '-5',
      transaction_date: '2026-06-07'
    }, @auth_env
    _(last_response.status).must_equal 200
    _(last_response.body).must_include 'must be greater than zero'
  end

  it 'creates transfer (two API calls) and redirects to /transactions' do
    req = stub_txn_create
    post '/transactions', {
      wallet_id: FEAT_WALLET_ID, to_wallet_id: 'wallet-2',
      title: 'CTBC to LINE Pay', transaction_type: 'transfer',
      amount: '500', transaction_date: '2026-06-07'
    }, @auth_env
    _(last_response.status).must_equal 302
    _(last_response.headers['Location']).must_equal '/transactions'
    assert_requested req, times: 2
  end

  # ── GET /transactions/:id ─────────────────────────────────────────────────

  it 'shows transaction details' do
    stub_txn_show
    get "/transactions/#{FEAT_TXN_ID}", {}, @auth_env
    _(last_response.status).must_equal 200
    _(last_response.body).must_include 'Coffee'
    _(last_response.body).must_include 'Transaction Details'
  end

  it 'redirects to /transactions when transaction not found' do
    stub_request(:get, "#{FEAT_API}/transactions/#{FEAT_TXN_ID}")
      .to_return(status: 404, body: { message: 'not found' }.to_json,
                 headers: { 'content-type' => 'application/json' })
    get "/transactions/#{FEAT_TXN_ID}", {}, @auth_env
    _(last_response.status).must_equal 302
    _(last_response.headers['Location']).must_equal '/transactions'
  end

  # ── GET /transactions/:id/edit ────────────────────────────────────────────

  it 'shows edit form pre-filled with current values' do
    stub_txn_show
    stub_categories
    get "/transactions/#{FEAT_TXN_ID}/edit", {}, @auth_env
    _(last_response.status).must_equal 200
    _(last_response.body).must_include 'Edit Transaction'
    _(last_response.body).must_include 'Coffee'
    _(last_response.body).must_include 'value="4.5"'
  end

  # ── POST /transactions/:id (update) ───────────────────────────────────────

  it 'updates transaction and redirects to show page' do
    stub_txn_update
    post "/transactions/#{FEAT_TXN_ID}", {
      title: 'Coffee updated', transaction_type: 'expense',
      amount: '5', transaction_date: '2026-06-07'
    }, @auth_env
    _(last_response.status).must_equal 302
    _(last_response.headers['Location']).must_equal "/transactions/#{FEAT_TXN_ID}"
  end

  it 'shows validation error and re-renders edit form for invalid update' do
    stub_txn_show
    stub_categories
    post "/transactions/#{FEAT_TXN_ID}", {
      title: '', transaction_type: 'expense',
      amount: '5', transaction_date: '2026-06-07'
    }, @auth_env
    _(last_response.status).must_equal 200
    _(last_response.body).must_include 'Edit Transaction'
  end

  # ── POST /transactions/:id/delete ─────────────────────────────────────────

  it 'deletes transaction and redirects to /transactions' do
    stub_txn_delete
    post "/transactions/#{FEAT_TXN_ID}/delete", {}, @auth_env
    _(last_response.status).must_equal 302
    _(last_response.headers['Location']).must_equal '/transactions'
  end

  it 'shows flash error when delete fails' do
    stub_request(:delete, "#{FEAT_API}/transactions/#{FEAT_TXN_ID}")
      .to_return(status: 500, body: { message: 'server error' }.to_json,
                 headers: { 'content-type' => 'application/json' })
    post "/transactions/#{FEAT_TXN_ID}/delete", {}, @auth_env
    _(last_response.status).must_equal 302
    _(last_response.headers['Location']).must_equal '/transactions'
  end
end
