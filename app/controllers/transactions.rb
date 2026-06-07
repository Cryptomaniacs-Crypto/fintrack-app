# frozen_string_literal: true

require_relative 'app'
require_relative '../forms/form_base'
require_relative '../forms/create_transaction'
require_relative '../services/create_transaction'
require_relative '../services/list_categories'
require_relative '../services/get_payment_method'
require_relative '../services/list_payment_methods'

module FinanceTracker
  class App < Roda
    route('transactions') do |routing|
      require_login!(routing)
      current_sess = FinanceTracker::CurrentSession.new(session)
      auth_token   = current_sess.auth_token

      # GET /transactions/new — unified form; pre-select wallet via ?wallet_id=
      routing.is 'new' do
        routing.get do
          wallets    = FinanceTracker::Services::ListPaymentMethods.new(App.config).call(auth_token: auth_token)
          categories = FinanceTracker::Services::ListCategories.new(App.config).call(auth_token: auth_token)
          view 'transactions/new', locals: {
            wallet:              nil,
            wallets:             wallets,
            preselect_wallet_id: routing.params['wallet_id'].to_s,
            categories:          categories,
            values:              {}
          }
        end
      end

      # POST /transactions — submitted from the unified form (wallet_id in body)
      routing.is do
        routing.post do
          form_params = routing.params.transform_keys(&:to_s)
          wallet_id   = form_params['wallet_id'].to_s.strip
          validation  = FinanceTracker::Form::CreateTransaction.call(form_params)

          if wallet_id.empty? || validation.failure?
            categories = FinanceTracker::Services::ListCategories.new(App.config).call(auth_token: auth_token)
            wallets    = FinanceTracker::Services::ListPaymentMethods.new(App.config).call(auth_token: auth_token)
            flash.now[:error] = wallet_id.empty? ? 'Please select a payment method' : FinanceTracker::Form.validation_errors(validation)
            next view 'transactions/new', locals: {
              wallet:              nil,
              wallets:             wallets,
              preselect_wallet_id: wallet_id,
              categories:          categories,
              values:              form_params
            }
          end

          FinanceTracker::Services::CreateTransaction.new(App.config).call(
            auth_token:       auth_token,
            wallet_id:        wallet_id,
            title:            validation[:title],
            transaction_type: validation[:transaction_type],
            amount:           validation[:amount],
            transaction_date: validation[:transaction_date],
            category_id:      validation[:category_id],
            note:             validation[:note]
          )

          flash[:notice] = 'Transaction recorded'
          routing.redirect "/payment-methods/#{wallet_id}"
        rescue StandardError => e
          flash[:error] = "Could not save transaction: #{e.message}"
          routing.redirect '/transactions/new'
        end
      end

      # /transactions/:wallet_id/new  and  POST /transactions/:wallet_id
      routing.on String do |wallet_id|
        wallet = FinanceTracker::Services::GetPaymentMethod.new(App.config)
                   .call(wallet_id: wallet_id, auth_token: auth_token)
        categories = FinanceTracker::Services::ListCategories.new(App.config)
                       .call(auth_token: auth_token)

        routing.get 'new' do
          view 'transactions/new', locals: {
            wallet:              wallet,
            wallets:             [],
            preselect_wallet_id: nil,
            categories:          categories,
            values:              {}
          }
        end

        routing.post do
          form_params = routing.params.transform_keys(&:to_s)
          validation  = FinanceTracker::Form::CreateTransaction.call(form_params)

          if validation.failure?
            flash.now[:error] = FinanceTracker::Form.validation_errors(validation)
            next view 'transactions/new', locals: {
              wallet:              wallet,
              wallets:             [],
              preselect_wallet_id: nil,
              categories:          categories,
              values:              form_params
            }
          end

          FinanceTracker::Services::CreateTransaction.new(App.config).call(
            auth_token:       auth_token,
            wallet_id:        wallet_id,
            title:            validation[:title],
            transaction_type: validation[:transaction_type],
            amount:           validation[:amount],
            transaction_date: validation[:transaction_date],
            category_id:      validation[:category_id],
            note:             validation[:note]
          )

          flash[:notice] = 'Transaction recorded'
          routing.redirect "/payment-methods/#{wallet_id}"
        rescue StandardError => e
          flash[:error] = "Could not save transaction: #{e.message}"
          routing.redirect "/transactions/#{wallet_id}/new"
        end

      rescue FinanceTracker::Services::GetPaymentMethod::NotFoundError
        flash[:error] = 'Payment method not found'
        routing.redirect '/payment-methods'
      end
    end
  end
end
