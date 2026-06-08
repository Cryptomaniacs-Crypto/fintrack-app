# frozen_string_literal: true

require_relative '../spec_helper'
require 'webmock/minitest'

# FintrackApi builds its ApiClient from FINTRACK_API_URL (default
# http://localhost:9292) and keeps the /api/v1 path, so bill-split calls hit
# "#{BS_API}/bill-splits...". Mirror ApiClient#url's /api/v1 handling here.
BS_API = begin
  base = ENV.fetch('FINTRACK_API_URL', 'http://localhost:9292').chomp('/')
  base.end_with?('/api/v1') ? base : "#{base}/api/v1"
end

BS_ID = 'bs-1'

BS_ATTRS = {
  'id' => BS_ID,
  'title' => 'Dinner at Nobu',
  'status' => 'pending',
  'creator_username' => 'tester',
  'grand_total' => '67.85',
  'tax_percent' => '10',
  'service_percent' => '5',
  'participants' => [
    { 'username' => 'tester', 'subtotal' => '20', 'tax' => '2', 'service' => '1', 'total' => '23', 'status' => 'agreed',   'reject_note' => '' },
    { 'username' => 'bob',    'subtotal' => '20', 'tax' => '2', 'service' => '1', 'total' => '23', 'status' => 'rejected', 'reject_note' => 'I had the salad' }
  ],
  'items' => [
    { 'name' => 'Pizza', 'amount' => '30', 'sharer_usernames' => %w[tester bob] }
  ]
}.freeze

BS_ENVELOPE = { 'data' => { 'type' => 'bill_split', 'attributes' => BS_ATTRS } }.freeze

def stub_bs_create
  stub_request(:post, "#{BS_API}/bill-splits")
    .to_return(status: 201, body: BS_ENVELOPE.to_json, headers: { 'content-type' => 'application/json' })
end

def stub_bs_get
  stub_request(:get, "#{BS_API}/bill-splits/#{BS_ID}")
    .to_return(status: 200, body: BS_ENVELOPE.to_json, headers: { 'content-type' => 'application/json' })
end

def stub_bs_list
  stub_request(:get, "#{BS_API}/bill-splits")
    .to_return(status: 200, body: { 'data' => [BS_ATTRS] }.to_json, headers: { 'content-type' => 'application/json' })
end

def stub_bs_action(action)
  stub_request(:post, "#{BS_API}/bill-splits/#{BS_ID}/#{action}")
    .to_return(status: 200, body: BS_ENVELOPE.to_json, headers: { 'content-type' => 'application/json' })
end

def stub_bs_update
  stub_request(:patch, "#{BS_API}/bill-splits/#{BS_ID}")
    .to_return(status: 200, body: BS_ENVELOPE.to_json, headers: { 'content-type' => 'application/json' })
end

describe 'Bill split routes' do
  include Rack::Test::Methods

  before do
    clear_cookies
    user         = { 'username' => 'tester', 'system_roles' => ['member'] }
    session_data = FinanceTracker::SecureMessage.encrypt(user.to_json)
    @auth_env    = { 'rack.session' => { 'current_account' => session_data } }
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

  # ── Step 1: new ──
  it 'shows the new bill split form with a participant field' do
    get '/bill-splits/new', {}, @auth_env
    _(last_response.status).must_equal 200
    _(last_response.body).must_include 'New Bill Split'
    _(last_response.body).must_include 'participant_username[]'
    _(last_response.body).must_include '/js/bill_split_form.js'
  end

  it 'creates a draft and redirects to the dishes editor' do
    stub_bs_create
    post '/bill-splits', { 'title' => 'Dinner at Nobu', 'participant_username' => %w[bob carol] }, @auth_env
    _(last_response.status).must_equal 302
    _(last_response.headers['Location']).must_equal "/bill-splits/#{BS_ID}/items"
  end

  # ── Step 2: items editor ──
  it 'shows the dishes editor with participants and tax/service fields' do
    stub_bs_get
    get "/bill-splits/#{BS_ID}/items", {}, @auth_env
    _(last_response.status).must_equal 200
    _(last_response.body).must_include 'Add Dishes'
    _(last_response.body).must_include 'Tax %'
    _(last_response.body).must_include 'tester'
    _(last_response.body).must_include 'bob'
  end

  it 'saves dishes and redirects to the detail page' do
    stub_bs_update
    post "/bill-splits/#{BS_ID}/items", {
      'title' => 'Dinner at Nobu', 'tax_percent' => '10', 'service_percent' => '5',
      'items' => { '0' => { 'name' => 'Pizza', 'amount' => '30', 'sharers' => %w[tester bob] } }
    }, @auth_env
    _(last_response.status).must_equal 302
    _(last_response.headers['Location']).must_equal "/bill-splits/#{BS_ID}"
  end

  # ── Detail + breakdown ──
  it 'shows the per-person breakdown and a rejection note' do
    stub_bs_get
    get "/bill-splits/#{BS_ID}", {}, @auth_env
    _(last_response.status).must_equal 200
    _(last_response.body).must_include 'Who owes what'
    _(last_response.body).must_include 'Dinner at Nobu'
    _(last_response.body).must_include '67.85'
    _(last_response.body).must_include 'I had the salad'
  end

  # ── Lifecycle actions ──
  it 'sends a bill split' do
    stub_bs_action('send')
    post "/bill-splits/#{BS_ID}/send", {}, @auth_env
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

  it 'settles a bill split' do
    stub_bs_action('settle')
    post "/bill-splits/#{BS_ID}/settle", {}, @auth_env
    _(last_response.status).must_equal 302
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
