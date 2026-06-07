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

      # GET /bill-splits/new
      routing.is 'new' do
        routing.get do
          view 'bill_splits/new', locals: { values: {} }
        end
      end

      routing.on String do |split_id|
        # POST /bill-splits/:id/agree
        routing.post 'agree' do
          api.agree_bill_split(split_id, auth_token: auth_token, account_api_token: account_api_token)
          flash[:notice] = 'You agreed to this bill split.'
          routing.redirect "/bill-splits/#{split_id}"
        rescue FinanceTracker::Services::ApiClient::ApiError => e
          flash[:error] = e.message
          routing.redirect "/bill-splits/#{split_id}"
        end

        # POST /bill-splits/:id/dispute
        routing.post 'dispute' do
          reason = routing.params['reason'].to_s.strip
          if reason.empty?
            flash[:error] = 'Please provide a reason for the dispute.'
            routing.redirect "/bill-splits/#{split_id}"
          end
          api.dispute_bill_split(split_id, reason: reason, auth_token: auth_token, account_api_token: account_api_token)
          flash[:notice] = 'Dispute submitted.'
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
          # GET /bill-splits/:id
          routing.get do
            result = api.get_bill_split(split_id, auth_token: auth_token, account_api_token: account_api_token)
            split  = result.dig('data', 'attributes') || result
            current_id = @current_account&.dig('id') || @current_account&.dig(:id)
            view 'bill_splits/show', locals: { split: split, current_account_id: current_id }
          rescue FinanceTracker::Services::ApiClient::ApiError => e
            flash[:error] = e.message
            routing.redirect '/bill-splits'
          end

          # PATCH /bill-splits/:id  (creator edits amount/reason)
          routing.patch do
            payload = {}
            payload[:amount]      = routing.params['amount']      unless routing.params['amount'].to_s.strip.empty?
            payload[:reason_note] = routing.params['reason_note'] unless routing.params['reason_note'].to_s.strip.empty?
            api.update_bill_split(split_id, payload, auth_token: auth_token, account_api_token: account_api_token)
            flash[:notice] = 'Bill split updated.'
            routing.redirect "/bill-splits/#{split_id}"
          rescue FinanceTracker::Services::ApiClient::ApiError => e
            flash[:error] = e.message
            routing.redirect "/bill-splits/#{split_id}"
          end

          # DELETE /bill-splits/:id  (creator deletes)
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
        # GET /bill-splits
        routing.get do
          result = api.list_bill_splits(auth_token: auth_token, account_api_token: account_api_token)
          splits = result['data'] || []
          current_id = @current_account&.dig('id') || @current_account&.dig(:id)
          view 'bill_splits/index', locals: { splits: splits, current_account_id: current_id }
        rescue FinanceTracker::Services::ApiClient::ApiError => e
          flash.now[:error] = "Could not load bill splits: #{e.message}"
          view 'bill_splits/index', locals: { splits: [], current_account_id: nil }
        end

        # POST /bill-splits
        routing.post do
          payload = {
            recipient_username: routing.params['recipient_username'].to_s.strip,
            amount:             routing.params['amount'].to_s.strip,
            reason_note:        routing.params['reason_note'].to_s.strip
          }
          result   = api.create_bill_split(payload, auth_token: auth_token, account_api_token: account_api_token)
          split_id = result.dig('data', 'attributes', 'id')
          flash[:notice] = 'Bill split created.'
          routing.redirect "/bill-splits/#{split_id}"
        rescue FinanceTracker::Services::ApiClient::ApiError => e
          flash.now[:error] = e.message
          view 'bill_splits/new', locals: { values: routing.params }
        end
      end
    end
  end
end
