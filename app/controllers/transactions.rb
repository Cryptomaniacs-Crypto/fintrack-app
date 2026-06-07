# frozen_string_literal: true

require_relative 'app'
require_relative '../forms/form_base'
require_relative '../forms/create_transaction'
require_relative '../services/create_transaction'
require_relative '../services/update_transaction'
require_relative '../services/delete_transaction'
require_relative '../services/get_transaction'
require_relative '../services/list_transactions'
require_relative '../services/list_categories'
require_relative '../services/list_payment_methods'

module FinanceTracker
  class App < Roda
    route('transactions') do |routing|
      require_login!(routing)
      current_sess = FinanceTracker::CurrentSession.new(session)
      auth_token   = current_sess.auth_token

      # GET /transactions/new — unified form with wallet selector + transfer support
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

      routing.is do
        # GET /transactions — My Transactions list
        routing.get do
          transactions = FinanceTracker::Services::ListTransactions.new(App.config)
                           .call(auth_token: auth_token)
          view 'transactions/index', locals: { transactions: transactions }
        rescue StandardError => e
          flash.now[:error] = "Could not load transactions: #{e.message}"
          view 'transactions/index', locals: { transactions: [] }
        end

        # POST /transactions — create (wallet_id + optional to_wallet_id in body)
        routing.post do
          form_params = routing.params.transform_keys(&:to_s)
          wallet_id   = form_params['wallet_id'].to_s.strip
          validation  = FinanceTracker::Form::CreateTransaction.call(form_params)

          if wallet_id.empty? || validation.failure?
            categories = FinanceTracker::Services::ListCategories.new(App.config).call(auth_token: auth_token)
            wallets    = FinanceTracker::Services::ListPaymentMethods.new(App.config).call(auth_token: auth_token)
            flash.now[:error] = wallet_id.empty? ? 'Please select an account' : FinanceTracker::Form.validation_errors(validation)
            next view 'transactions/new', locals: {
              wallet:              nil,
              wallets:             wallets,
              preselect_wallet_id: wallet_id,
              categories:          categories,
              values:              form_params
            }
          end

          if validation[:transaction_type] == 'transfer'
            to_wallet_id = validation[:to_wallet_id].to_s.strip
            FinanceTracker::Services::CreateTransaction.new(App.config).call(
              auth_token:       auth_token,
              wallet_id:        wallet_id,
              title:            "Transfer → #{validation[:title]}",
              transaction_type: 'expense',
              amount:           validation[:amount],
              transaction_date: validation[:transaction_date],
              note:             validation[:note]
            )
            FinanceTracker::Services::CreateTransaction.new(App.config).call(
              auth_token:       auth_token,
              wallet_id:        to_wallet_id,
              title:            "Transfer ← #{validation[:title]}",
              transaction_type: 'income',
              amount:           validation[:amount],
              transaction_date: validation[:transaction_date],
              note:             validation[:note]
            )
            flash[:notice] = 'Transfer recorded'
            routing.redirect '/transactions'
          else
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
          end
        rescue StandardError => e
          flash[:error] = "Could not save transaction: #{e.message}"
          routing.redirect '/transactions/new'
        end
      end

      # /transactions/:id — show, edit, update, delete
      routing.on String do |transaction_id|
        # GET /transactions/:id/edit
        routing.is 'edit' do
          routing.get do
            txn        = FinanceTracker::Services::GetTransaction.new(App.config).call(transaction_id: transaction_id, auth_token: auth_token)
            categories = FinanceTracker::Services::ListCategories.new(App.config).call(auth_token: auth_token)
            # Pre-populate form values from the stored transaction
            stored_type = txn.amount.to_f.negative? ? 'expense' : 'income'
            prefill = {
              'title'            => txn.title.to_s,
              'transaction_type' => stored_type,
              'amount'           => txn.amount.to_f.abs.to_s,
              'transaction_date' => txn.transaction_date.to_s,
              'category_id'      => txn.category_id.to_s,
              'note'             => txn.note.to_s
            }
            view 'transactions/edit', locals: { txn: txn, categories: categories, values: prefill }
          rescue FinanceTracker::Services::GetTransaction::NotFoundError
            flash[:error] = 'Transaction not found'
            routing.redirect '/transactions'
          end
        end

        # POST /transactions/:id/delete — delete with confirmation
        routing.is 'delete' do
          routing.post do
            FinanceTracker::Services::DeleteTransaction.new(App.config)
              .call(transaction_id: transaction_id, auth_token: auth_token)
            flash[:notice] = 'Transaction deleted'
            routing.redirect '/transactions'
          rescue StandardError => e
            flash[:error] = "Could not delete transaction: #{e.message}"
            routing.redirect '/transactions'
          end
        end

        routing.is do
          # GET /transactions/:id — show
          routing.get do
            txn = FinanceTracker::Services::GetTransaction.new(App.config)
                    .call(transaction_id: transaction_id, auth_token: auth_token)
            view 'transactions/show', locals: { txn: txn }
          rescue FinanceTracker::Services::GetTransaction::NotFoundError
            flash[:error] = 'Transaction not found'
            routing.redirect '/transactions'
          rescue StandardError => e
            flash[:error] = "Could not load transaction: #{e.message}"
            routing.redirect '/transactions'
          end

          # POST /transactions/:id — update
          routing.post do
            form_params = routing.params.transform_keys(&:to_s)
            validation  = FinanceTracker::Form::UpdateTransaction.call(form_params)

            if validation.failure?
              categories = FinanceTracker::Services::ListCategories.new(App.config).call(auth_token: auth_token)
              txn        = FinanceTracker::Services::GetTransaction.new(App.config).call(transaction_id: transaction_id, auth_token: auth_token)
              flash.now[:error] = FinanceTracker::Form.validation_errors(validation)
              next view 'transactions/edit', locals: { txn: txn, categories: categories, values: form_params }
            end

            FinanceTracker::Services::UpdateTransaction.new(App.config).call(
              auth_token:       auth_token,
              transaction_id:   transaction_id,
              title:            validation[:title],
              transaction_type: validation[:transaction_type],
              amount:           validation[:amount],
              transaction_date: validation[:transaction_date],
              category_id:      validation[:category_id],
              note:             validation[:note]
            )

            flash[:notice] = 'Transaction updated'
            routing.redirect "/transactions/#{transaction_id}"
          rescue StandardError => e
            flash[:error] = "Could not update transaction: #{e.message}"
            routing.redirect "/transactions/#{transaction_id}/edit"
          end
        end
      end
    end
  end
end
