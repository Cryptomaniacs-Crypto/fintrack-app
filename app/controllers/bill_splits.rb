# frozen_string_literal: true

require_relative 'app'
require_relative '../services/fintrack_api'
require_relative '../models/current_session'

module FinanceTracker
  class App < Roda
    route('bill-splits') do |routing|
      require_login!(routing)
      current_sess      = FinanceTracker::CurrentSession.new(session)
      auth_token        = current_sess.auth_token
      account_api_token = current_sess.account_api_token
      api               = FinanceTracker::Services::FintrackApi.new
      current_username  = @current_account && @current_account['username']

      # GET /bill-splits/new — Step 1: name the bill and add participants
      routing.is 'new' do
        routing.get do
          view 'bill_splits/new', locals: { values: {} }
        end
      end

      routing.on String do |split_id|
        # GET/POST /bill-splits/:id/items — Step 2: dishes + tax/service editor
        routing.on 'items' do
          routing.get do
            bill = fetch_bill(api, split_id, auth_token, account_api_token)
            view 'bill_splits/items', locals: { bill: bill }
          rescue FinanceTracker::Services::ApiClient::ApiError => e
            flash[:error] = e.message
            routing.redirect '/bill-splits'
          end

          routing.post do
            payload = {
              title:           routing.params['title'],
              tax_percent:     routing.params['tax_percent'].to_s.strip,
              service_percent: routing.params['service_percent'].to_s.strip,
              items:           build_bill_split_items(routing.params)
            }
            api.update_bill_split(split_id, payload, auth_token: auth_token, account_api_token: account_api_token)
            flash[:notice] = 'Dishes saved.'
            routing.redirect "/bill-splits/#{split_id}"
          rescue FinanceTracker::Services::ApiClient::ApiError => e
            flash.now[:error] = e.message
            bill = (fetch_bill(api, split_id, auth_token, account_api_token) rescue nil)
            view 'bill_splits/items', locals: { bill: bill }
          end
        end

        # POST /bill-splits/:id/send — confirm and send the draft
        routing.post 'send' do
          api.send_bill_split(split_id, auth_token: auth_token, account_api_token: account_api_token)
          flash[:notice] = 'Bill split sent to participants.'
          routing.redirect "/bill-splits/#{split_id}"
        rescue FinanceTracker::Services::ApiClient::ApiError => e
          flash[:error] = e.message
          routing.redirect "/bill-splits/#{split_id}"
        end

        # POST /bill-splits/:id/agree
        routing.post 'agree' do
          api.agree_bill_split(split_id, auth_token: auth_token, account_api_token: account_api_token)
          flash[:notice] = 'You agreed to this bill split.'
          routing.redirect "/bill-splits/#{split_id}"
        rescue FinanceTracker::Services::ApiClient::ApiError => e
          flash[:error] = e.message
          routing.redirect "/bill-splits/#{split_id}"
        end

        # POST /bill-splits/:id/reject — with a reason note
        routing.post 'reject' do
          reason = routing.params['reason'].to_s.strip
          if reason.empty?
            flash[:error] = 'Please provide a reason for the rejection.'
            routing.redirect "/bill-splits/#{split_id}"
          end
          api.reject_bill_split(split_id, reason: reason, auth_token: auth_token, account_api_token: account_api_token)
          flash[:notice] = 'Rejection submitted.'
          routing.redirect "/bill-splits/#{split_id}"
        rescue FinanceTracker::Services::ApiClient::ApiError => e
          flash[:error] = e.message
          routing.redirect "/bill-splits/#{split_id}"
        end

        # POST /bill-splits/:id/settle
        routing.post 'settle' do
          api.settle_bill_split(split_id, auth_token: auth_token, account_api_token: account_api_token)
          flash[:notice] = 'Bill split marked as settled.'
          routing.redirect "/bill-splits/#{split_id}"
        rescue FinanceTracker::Services::ApiClient::ApiError => e
          flash[:error] = e.message
          routing.redirect "/bill-splits/#{split_id}"
        end

        routing.is do
          # GET /bill-splits/:id — breakdown + actions
          routing.get do
            bill = fetch_bill(api, split_id, auth_token, account_api_token)
            view 'bill_splits/show', locals: { bill: bill, current_username: current_username }
          rescue FinanceTracker::Services::ApiClient::ApiError => e
            flash[:error] = e.message
            routing.redirect '/bill-splits'
          end

          # DELETE /bill-splits/:id
          routing.delete do
            api.delete_bill_split(split_id, auth_token: auth_token, account_api_token: account_api_token)
            flash[:notice] = 'Bill split deleted.'
            routing.redirect '/bill-splits'
          rescue FinanceTracker::Services::ApiClient::ApiError => e
            flash[:error] = e.message
            routing.redirect "/bill-splits/#{split_id}"
          end
        end
      end

      routing.is do
        # GET /bill-splits — list bills I created or participate in
        routing.get do
          result = api.list_bill_splits(auth_token: auth_token, account_api_token: account_api_token)
          splits = result['data'] || []
          view 'bill_splits/index', locals: { splits: splits, current_username: current_username }
        rescue FinanceTracker::Services::ApiClient::ApiError => e
          flash.now[:error] = "Could not load bill splits: #{e.message}"
          view 'bill_splits/index', locals: { splits: [], current_username: current_username }
        end

        # POST /bill-splits — create a draft, then go to the dishes editor
        routing.post do
          usernames = Array(routing.params['participant_username']).map { |name| name.to_s.strip }.reject(&:empty?)
          payload = { title: routing.params['title'].to_s.strip, participant_usernames: usernames }
          result   = api.create_bill_split(payload, auth_token: auth_token, account_api_token: account_api_token)
          split_id = result.dig('data', 'attributes', 'id')
          flash[:notice] = 'Draft created — now add the dishes.'
          routing.redirect "/bill-splits/#{split_id}/items"
        rescue FinanceTracker::Services::ApiClient::ApiError => e
          flash.now[:error] = e.message
          view 'bill_splits/new', locals: { values: routing.params }
        end
      end
    end

    private

    # Fetch a bill split and return its attributes hash (participants, items,
    # breakdown, status).
    def fetch_bill(api, split_id, auth_token, account_api_token)
      result = api.get_bill_split(split_id, auth_token: auth_token, account_api_token: account_api_token)
      result.dig('data', 'attributes') || result
    end

    # Build the API `items` array from the dish editor's namespaced form fields:
    #   items[<i>][name], items[<i>][amount], items[<i>][sharers][]
    # Rack parses these into a hash keyed by i; the index only needs to be
    # unique per row (gaps are fine), so add/remove in the UI stays consistent.
    def build_bill_split_items(params)
      raw = params['items']
      rows = raw.is_a?(Hash) ? raw.values : Array(raw)
      rows.filter_map do |row|
        next unless row.is_a?(Hash)

        name = row['name'].to_s.strip
        next if name.empty?

        { name: name, amount: row['amount'].to_s.strip, sharer_usernames: Array(row['sharers']) }
      end
    end
  end
end
