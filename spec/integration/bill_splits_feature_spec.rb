# frozen_string_literal: true

require_relative '../spec_helper'
require 'webmock/minitest'
require 'base64'

# FintrackApi builds its ApiClient from FINTRACK_API_URL (default
# http://localhost:9292) and keeps the /api/v1 path, so bill-split calls hit
# "#{BS_API}/bill-splits...". Mirror ApiClient#url's /api/v1 handling here.
BS_API = begin
  base = ENV.fetch('FINTRACK_API_URL', 'http://localhost:9292').chomp('/')
  base.end_with?('/api/v1') ? base : "#{base}/api/v1"
end

BS_ID = 'bs-1'
PART_TESTER = 'p-tester'
PART_BOB = 'p-bob'
PART_CAROL = 'p-carol'

# A valid 1x1 PNG for proof tests.
PNG_1PX = 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg=='

BS_ATTRS = {
  'id' => BS_ID,
  'title' => 'Dinner at Nobu',
  'status' => 'pending',
  'creator_username' => 'tester',
  'creator_wallet_id' => nil,
  'grand_total' => '69.00',
  'tax_percent' => '10',
  'service_percent' => '5',
  'participants' => [
    { 'participant_id' => PART_TESTER, 'username' => 'tester', 'is_owner' => true,  'status' => 'settled',  'total' => '23', 'has_proof' => false, 'reject_note' => '' },
    { 'participant_id' => PART_BOB,    'username' => 'bob',    'is_owner' => false, 'status' => 'rejected', 'total' => '23', 'has_proof' => false, 'reject_note' => 'I had the salad' },
    { 'participant_id' => PART_CAROL,  'username' => 'carol',  'is_owner' => false, 'status' => 'paid',     'total' => '23', 'has_proof' => true,  'reject_note' => '' }
  ],
  'items' => [
    { 'name' => 'Pizza', 'amount' => '30', 'sharer_usernames' => %w[tester bob carol] }
  ]
}.freeze

BS_ENVELOPE = { 'data' => { 'type' => 'bill_split', 'attributes' => BS_ATTRS } }.freeze
WALLETS_ENVELOPE = { 'data' => [{ 'id' => 'w1', 'attributes' => { 'name' => 'Cash', 'balance' => '0', 'method_type' => 'cash' } }] }.freeze

def stub_bs_create
  stub_request(:post, "#{BS_API}/bill-splits")
    .to_return(status: 201, body: BS_ENVELOPE.to_json, headers: { 'content-type' => 'application/json' })
end

def stub_bs_get
  stub_request(:get, "#{BS_API}/bill-splits/#{BS_ID}")
    .to_return(status: 200, body: BS_ENVELOPE.to_json, headers: { 'content-type' => 'application/json' })
end

def stub_bs_wallets
  stub_request(:get, "#{BS_API}/wallets")
    .to_return(status: 200, body: WALLETS_ENVELOPE.to_json, headers: { 'content-type' => 'application/json' })
end

def stub_bs_list
  stub_request(:get, "#{BS_API}/bill-splits")
    .to_return(status: 200, body: { 'data' => [BS_ATTRS] }.to_json, headers: { 'content-type' => 'application/json' })
end

def stub_bs_action(action)
  stub_request(:post, "#{BS_API}/bill-splits/#{BS_ID}/#{action}")
    .to_return(status: 200, body: BS_ENVELOPE.to_json, headers: { 'content-type' => 'application/json' })
end

def stub_bs_confirm(pid)
  stub_request(:post, "#{BS_API}/bill-splits/#{BS_ID}/participants/#{pid}/confirm")
    .to_return(status: 200, body: BS_ENVELOPE.to_json, headers: { 'content-type' => 'application/json' })
end

def stub_bs_proof(pid)
  stub_request(:get, "#{BS_API}/bill-splits/#{BS_ID}/participants/#{pid}/proof")
    .to_return(status: 200, body: { 'content_type' => 'image/png', 'image_base64' => PNG_1PX }.to_json,
               headers: { 'content-type' => 'application/json' })
end

def stub_bs_update
  stub_request(:patch, "#{BS_API}/bill-splits/#{BS_ID}")
    .to_return(status: 200, body: BS_ENVELOPE.to_json, headers: { 'content-type' => 'application/json' })
end

describe 'Bill split routes' do
  include Rack::Test::Methods

  def session_env(username)
    user = { 'username' => username, 'system_roles' => ['member'] }
    { 'rack.session' => { 'current_account' => FinanceTracker::SecureMessage.encrypt(user.to_json) } }
  end

  before do
    clear_cookies
    @auth_env = session_env('tester')
  end

  after { WebMock.reset! }

  # ── Auth guards ──
  it 'redirects guests from GET /bill-splits to login' do
    get '/bill-splits'
    _(last_response.status).must_equal 302
    _(last_response.headers['Location']).must_equal '/auth/login'
  end

  it 'redirects guests from GET /bill-splits/new to login' do
    get '/bill-splits/new'
    _(last_response.status).must_equal 302
    _(last_response.headers['Location']).must_equal '/auth/login'
  end

  # ── Step 1 / Step 2 ──
  it 'shows the new bill split form with a participant field' do
    get '/bill-splits/new', {}, @auth_env
    _(last_response.status).must_equal 200
    _(last_response.body).must_include 'New Bill Split'
    _(last_response.body).must_include 'participant_username[]'
  end

  it 'creates a draft and redirects to the dishes editor' do
    stub_bs_create
    post '/bill-splits', { 'title' => 'Dinner at Nobu', 'participant_username' => %w[bob carol] }, @auth_env
    _(last_response.status).must_equal 302
    _(last_response.headers['Location']).must_equal "/bill-splits/#{BS_ID}/items"
  end

  it 'shows the dishes editor with participants' do
    stub_bs_get
    get "/bill-splits/#{BS_ID}/items", {}, @auth_env
    _(last_response.status).must_equal 200
    _(last_response.body).must_include 'Add Dishes'
    _(last_response.body).must_include 'Tax %'
  end

  it 'saves dishes and redirects to the detail page' do
    stub_bs_update
    post "/bill-splits/#{BS_ID}/items", {
      'title' => 'Dinner at Nobu', 'tax_percent' => '10', 'service_percent' => '5',
      'items' => { '0' => { 'name' => 'Pizza', 'amount' => '30', 'sharers' => %w[tester bob carol] } }
    }, @auth_env
    _(last_response.status).must_equal 302
    _(last_response.headers['Location']).must_equal "/bill-splits/#{BS_ID}"
  end

  # ── Detail + breakdown (owner view) ──
  it 'shows the breakdown plus owner payment controls' do
    stub_bs_get
    stub_bs_wallets
    get "/bill-splits/#{BS_ID}", {}, @auth_env
    _(last_response.status).must_equal 200
    _(last_response.body).must_include 'Who owes what'
    _(last_response.body).must_include 'Payments'        # owner confirm section
    _(last_response.body).must_include 'Confirm received' # carol is 'paid'
    _(last_response.body).must_include 'view proof'        # carol has_proof
  end

  it 'hides the reject form once the participant has already rejected' do
    stub_bs_get
    stub_bs_wallets
    get "/bill-splits/#{BS_ID}", {}, session_env('bob')
    _(last_response.status).must_equal 200
    _(last_response.body).must_include 'You rejected'
    _(last_response.body).wont_include 'name="reason"'
  end

  # ── Lifecycle actions ──
  it 'sends a bill split (optionally with an upfront wallet)' do
    stub_bs_action('send')
    post "/bill-splits/#{BS_ID}/send", { 'wallet_id' => 'w1' }, @auth_env
    _(last_response.status).must_equal 302
  end

  it 'lets a participant agree' do
    stub_bs_action('agree')
    post "/bill-splits/#{BS_ID}/agree", {}, @auth_env
    _(last_response.status).must_equal 302
  end

  it 'rejects with a reason' do
    stub_bs_action('reject')
    post "/bill-splits/#{BS_ID}/reject", { 'reason' => 'Wrong amount' }, @auth_env
    _(last_response.status).must_equal 302
  end

  it 'blocks a reject with no reason without calling the API' do
    post "/bill-splits/#{BS_ID}/reject", { 'reason' => '' }, @auth_env
    _(last_response.status).must_equal 302
    _(last_response.headers['Location']).must_equal "/bill-splits/#{BS_ID}"
  end

  # ── Phase 2: pay / confirm / proof ──
  it 'records a participant payment' do
    stub_bs_action('pay')
    post "/bill-splits/#{BS_ID}/pay", { 'wallet_id' => 'w1' }, session_env('carol')
    _(last_response.status).must_equal 302
  end

  it 'lets the owner confirm a payment' do
    stub_bs_confirm(PART_CAROL)
    post "/bill-splits/#{BS_ID}/participants/#{PART_CAROL}/confirm", { 'wallet_id' => 'w1' }, @auth_env
    _(last_response.status).must_equal 302
  end

  it 'streams a participant proof image' do
    stub_bs_proof(PART_CAROL)
    get "/bill-splits/#{BS_ID}/participants/#{PART_CAROL}/proof", {}, @auth_env
    _(last_response.status).must_equal 200
    _(last_response.headers['Content-Type']).must_equal 'image/png'
    _(last_response.body).must_equal Base64.strict_decode64(PNG_1PX)
  end

  # ── List ──
  it 'lists bill splits for the logged-in user' do
    stub_bs_list
    get '/bill-splits', {}, @auth_env
    _(last_response.status).must_equal 200
    _(last_response.body).must_include 'My Bill Splits'
    _(last_response.body).must_include 'Dinner at Nobu'
  end
end
