# frozen_string_literal: true

require_relative 'app'
require_relative '../forms/form_base'
require_relative '../forms/create_payment_method'
require_relative '../services/list_payment_methods'
require_relative '../services/create_payment_method'
require_relative '../services/get_payment_method'
require_relative '../services/list_transactions'

module FinanceTracker
  class App < Roda
    METHOD_TYPE_LABELS = {
      'cash' => 'Cash',
      'bank_account' => 'Bank Account',
      'credit_card' => 'Credit Card',
      'debit_card' => 'Debit Card',
      'e_wallet' => 'E-Wallet'
    }.freeze

    route('payment-methods') do |routing|
      require_login!(routing)
      current_sess    = FinanceTracker::CurrentSession.new(session)
      auth_token      = current_sess.auth_token
      # Any logged-in user with a full-scope token can create wallets
      can_create = !auth_token.to_s.empty?

      # GET /payment-methods/new
      routing.is 'new' do
        routing.get do
          view 'payment_methods/new', locals: { can_create_payment_method: can_create }
        end
      end

      # /payment-methods/:id  (show page)
      routing.on String do |wallet_id|
        routing.get do
          wallet = FinanceTracker::Services::GetPaymentMethod.new(App.config)
                     .call(wallet_id: wallet_id, auth_token: auth_token)
          transactions = FinanceTracker::Services::ListTransactions.new(App.config)
                           .call(auth_token: auth_token, wallet_id: wallet_id)

          opening  = wallet.balance.to_f
          current_balance = opening + transactions.sum { |t| t.amount.to_f }

          view 'payment_methods/show', locals: {
            wallet: wallet,
            transactions: transactions,
            opening_balance: opening,
            current_balance: current_balance,
            method_type_label: METHOD_TYPE_LABELS.fetch(wallet.method_type.to_s, wallet.method_type.to_s)
          }
        rescue FinanceTracker::Services::GetPaymentMethod::NotFoundError
          flash[:error] = 'Payment method not found'
          routing.redirect '/payment-methods'
        rescue StandardError => e
          flash[:error] = "Could not load payment method: #{e.message}"
          routing.redirect '/payment-methods'
        end
      end

      routing.is do
        # GET /payment-methods
        routing.get do
          payment_methods = FinanceTracker::Services::ListPaymentMethods.new(App.config).call(
            auth_token: auth_token
          )
          view 'payment_methods/index', locals: {
            payment_methods: payment_methods,
            can_create_payment_method: can_create,
            method_type_labels: METHOD_TYPE_LABELS
          }
        rescue StandardError => e
          flash[:error] = "Could not load payment methods: #{e.message}"
          view 'payment_methods/index', locals: {
            payment_methods: [],
            can_create_payment_method: can_create,
            method_type_labels: METHOD_TYPE_LABELS
          }
        end

        # POST /payment-methods
        routing.post do
          form_params = routing.params.transform_keys(&:to_s)
          validation  = FinanceTracker::Form::CreatePaymentMethod.call(form_params)

          if validation.failure?
            flash.now[:error] = FinanceTracker::Form.validation_errors(validation)
            next view 'payment_methods/new', locals: {
              can_create_payment_method: can_create,
              values: form_params
            }
          end

          result = FinanceTracker::Services::CreatePaymentMethod.new(App.config).call(
            auth_token:    auth_token,
            name:          validation[:name],
            method_type:   validation[:method_type],
            account_number: validation[:account_number],
            balance:       validation[:balance]
          )

          new_id = result.dig('data', 'attributes', 'id') || result.dig('data', 'id')
          flash[:notice] = 'Payment method added'
          if new_id
            routing.redirect "/payment-methods/#{new_id}"
          else
            routing.redirect '/payment-methods'
          end
        rescue StandardError => e
          flash[:error] = "Could not create payment method: #{e.message}"
          routing.redirect '/payment-methods/new'
        end
      end
    end
  end
end
