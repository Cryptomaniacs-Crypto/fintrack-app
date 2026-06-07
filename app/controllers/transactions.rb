# frozen_string_literal: true

require_relative 'app'
require_relative '../forms/form_base'
require_relative '../forms/create_transaction'
require_relative '../services/create_transaction'
require_relative '../services/list_categories'
require_relative '../services/get_payment_method'

module FinanceTracker
  class App < Roda
    route('transactions') do |routing|
      require_login!(routing)
      current_sess = FinanceTracker::CurrentSession.new(session)
      auth_token   = current_sess.auth_token

      # Routes nested under a wallet: /transactions/:wallet_id/new  and
      #                               POST /transactions/:wallet_id
      routing.on String do |wallet_id|
        wallet = FinanceTracker::Services::GetPaymentMethod.new(App.config)
                   .call(wallet_id: wallet_id, auth_token: auth_token)

        categories = FinanceTracker::Services::ListCategories.new(App.config)
                       .call(auth_token: auth_token)

        # GET /transactions/:wallet_id/new
        routing.get 'new' do
          view 'transactions/new', locals: {
            wallet: wallet,
            categories: categories,
            values: {}
          }
        end

        # POST /transactions/:wallet_id
        routing.post do
          form_params = routing.params.transform_keys(&:to_s)
          validation  = FinanceTracker::Form::CreateTransaction.call(form_params)

          if validation.failure?
            flash.now[:error] = FinanceTracker::Form.validation_errors(validation)
            next view 'transactions/new', locals: {
              wallet: wallet,
              categories: categories,
              values: form_params
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
