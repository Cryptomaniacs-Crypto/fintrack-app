# frozen_string_literal: true

require_relative 'app'
require_relative '../forms/form_base'
require_relative '../forms/create_payment_method'
require_relative '../forms/update_payment_method'
require_relative '../services/list_payment_methods'
require_relative '../services/create_payment_method'
require_relative '../services/update_wallet'
require_relative '../services/delete_wallet'
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
          view 'payment_methods/new', locals: { can_create_payment_method: can_create, values: {} }
        end
      end

      # /payment-methods/:id
      routing.on String do |wallet_id|
        # GET /payment-methods/:id/edit
        routing.is 'edit' do
          routing.get do
            wallet = FinanceTracker::Services::GetPaymentMethod.new(App.config)
                       .call(wallet_id: wallet_id, auth_token: auth_token)
            prefill = {
              'name'           => wallet.name.to_s,
              'account_number' => wallet.account_number.to_s
            }
            view 'payment_methods/edit', locals: {
              wallet:     wallet,
              values:     prefill,
              method_type_label: METHOD_TYPE_LABELS.fetch(wallet.method_type.to_s, wallet.method_type.to_s)
            }
          rescue FinanceTracker::Services::GetPaymentMethod::NotFoundError
            flash[:error] = 'Payment method not found'
            routing.redirect '/payment-methods'
          end
        end

        # POST /payment-methods/:id/delete — delete with confirmation
        routing.is 'delete' do
          routing.post do
            FinanceTracker::Services::DeleteWallet.new(App.config)
              .call(wallet_id: wallet_id, auth_token: auth_token)
            flash[:notice] = 'Wallet deleted'
            routing.redirect '/payment-methods'
          rescue StandardError => e
            flash[:error] = "Could not delete wallet: #{e.message}"
            routing.redirect "/payment-methods/#{wallet_id}"
          end
        end

        routing.is do
          # GET /payment-methods/:id — show page
          routing.get do
            wallet = FinanceTracker::Services::GetPaymentMethod.new(App.config)
                       .call(wallet_id: wallet_id, auth_token: auth_token)
            transactions = FinanceTracker::Services::ListTransactions.new(App.config)
                             .call(auth_token: auth_token, wallet_id: wallet_id)

            opening         = wallet.balance.to_f
            current_balance = opening + transactions.sum { |t| t.amount.to_f }

            view 'payment_methods/show', locals: {
              wallet:            wallet,
              transactions:      transactions,
              opening_balance:   opening,
              current_balance:   current_balance,
              method_type_label: METHOD_TYPE_LABELS.fetch(wallet.method_type.to_s, wallet.method_type.to_s)
            }
          rescue FinanceTracker::Services::GetPaymentMethod::NotFoundError
            flash[:error] = 'Payment method not found'
            routing.redirect '/payment-methods'
          rescue StandardError => e
            flash[:error] = "Could not load payment method: #{e.message}"
            routing.redirect '/payment-methods'
          end

          # POST /payment-methods/:id — update
          routing.post do
            form_params = routing.params.transform_keys(&:to_s)
            validation  = FinanceTracker::Form::UpdatePaymentMethod.call(form_params)

            if validation.failure?
              wallet = FinanceTracker::Services::GetPaymentMethod.new(App.config)
                         .call(wallet_id: wallet_id, auth_token: auth_token)
              flash.now[:error] = FinanceTracker::Form.validation_errors(validation)
              next view 'payment_methods/edit', locals: {
                wallet:            wallet,
                values:            form_params,
                method_type_label: METHOD_TYPE_LABELS.fetch(wallet.method_type.to_s, wallet.method_type.to_s)
              }
            end

            FinanceTracker::Services::UpdateWallet.new(App.config).call(
              auth_token:     auth_token,
              wallet_id:      wallet_id,
              name:           validation[:name],
              account_number: validation[:account_number]
            )
            flash[:notice] = 'Wallet updated'
            routing.redirect "/payment-methods/#{wallet_id}"
          rescue StandardError => e
            flash[:error] = "Could not update wallet: #{e.message}"
            routing.redirect "/payment-methods/#{wallet_id}/edit"
          end
        end
      end

      routing.is do
        # GET /payment-methods
        routing.get do
          payment_methods = FinanceTracker::Services::ListPaymentMethods.new(App.config).call(
            auth_token: auth_token
          )
          all_transactions = FinanceTracker::Services::ListTransactions.new(App.config).call(
            auth_token: auth_token
          )
          tx_sums = all_transactions.group_by(&:wallet_id)
                                    .transform_values { |txns| txns.sum { |t| t.amount.to_f } }
          wallet_balances = payment_methods.each_with_object({}) do |w, h|
            h[w.id] = w.balance.to_f + tx_sums.fetch(w.id.to_s, 0.0)
          end
          view 'payment_methods/index', locals: {
            payment_methods:  payment_methods,
            wallet_balances:  wallet_balances,
            can_create_payment_method: can_create,
            method_type_labels: METHOD_TYPE_LABELS
          }
        rescue StandardError => e
          flash[:error] = "Could not load payment methods: #{e.message}"
          view 'payment_methods/index', locals: {
            payment_methods:  [],
            wallet_balances:  {},
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
