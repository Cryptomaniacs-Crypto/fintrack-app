# frozen_string_literal: true

require 'csv'
require 'date'
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

      # GET /transactions/export — download the (optionally filtered) list as CSV
      routing.get 'export' do
        transactions = FinanceTracker::Services::ListTransactions.new(App.config)
                         .call(auth_token: auth_token)
        rows = filter_transactions(transactions, routing.params)
        response['Content-Type'] = 'text/csv; charset=utf-8'
        response['Content-Disposition'] = %(attachment; filename="transactions-#{Date.today}.csv")
        transactions_to_csv(rows)
      rescue StandardError => e
        flash[:error] = "Could not export transactions: #{e.message}"
        routing.redirect '/transactions'
      end

      routing.is do
        # GET /transactions — My Transactions list (with search + filters)
        routing.get do
          transactions = FinanceTracker::Services::ListTransactions.new(App.config)
                           .call(auth_token: auth_token)
          categories = (FinanceTracker::Services::ListCategories.new(App.config).call(auth_token: auth_token) rescue [])
          wallets    = (FinanceTracker::Services::ListPaymentMethods.new(App.config).call(auth_token: auth_token) rescue [])
          view 'transactions/index', locals: {
            transactions: filter_transactions(transactions, routing.params),
            total_count:  transactions.size,
            categories:   categories,
            wallets:      wallets,
            filters:      extract_filters(routing.params)
          }
        rescue StandardError => e
          flash.now[:error] = "Could not load transactions: #{e.message}"
          view 'transactions/index', locals: {
            transactions: [], total_count: 0, categories: [], wallets: [], filters: extract_filters(routing.params)
          }
        end

        # POST /transactions — create (wallet_id + optional to_wallet_id in body)
        routing.post do
          form_params = routing.params.transform_keys(&:to_s)
          wallet_id   = form_params['wallet_id'].to_s.strip
          validation  = FinanceTracker::Form::CreateTransaction.call(form_params)

          if wallet_id.empty? || validation.failure?
            categories = FinanceTracker::Services::ListCategories.new(App.config).call(auth_token: auth_token)
            wallets    = FinanceTracker::Services::ListPaymentMethods.new(App.config).call(auth_token: auth_token)
            flash.now[:error] = wallet_id.empty? ? 'Please select a wallet' : FinanceTracker::Form.validation_errors(validation)
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

    private

    # The filter values currently in effect, echoed back to the view so the
    # form stays populated and the export link can carry them.
    def extract_filters(params)
      {
        'q'           => params['q'].to_s,
        'type'        => params['type'].to_s,
        'category_id' => params['category_id'].to_s,
        'wallet_id'   => params['wallet_id'].to_s,
        'date_from'   => params['date_from'].to_s,
        'date_to'     => params['date_to'].to_s
      }
    end

    # Apply search + filters to a list of Transaction models. All criteria are
    # AND-combined; blank criteria are ignored.
    def filter_transactions(transactions, params)
      f         = extract_filters(params)
      q         = f['q'].strip.downcase
      type      = f['type'].strip
      cat       = f['category_id'].strip
      wallet    = f['wallet_id'].strip
      date_from = parse_filter_date(f['date_from'])
      date_to   = parse_filter_date(f['date_to'])

      transactions.select do |t|
        next false if !q.empty? && !"#{t.title} #{t.note}".downcase.include?(q)

        case type
        when 'income'   then next false unless t.income?  && !t.transfer?
        when 'expense'  then next false unless t.expense? && !t.transfer?
        when 'transfer' then next false unless t.transfer?
        end

        next false if !cat.empty?    && t.category_id.to_s != cat
        next false if !wallet.empty? && t.wallet_id.to_s != wallet

        if date_from || date_to
          d = parse_filter_date(t.transaction_date)
          next false if d.nil?
          next false if date_from && d < date_from
          next false if date_to   && d > date_to
        end

        true
      end
    end

    def parse_filter_date(value)
      str = value.to_s.strip
      return nil if str.empty?

      Date.parse(str)
    rescue ArgumentError
      nil
    end

    # Render the given transactions as a CSV string.
    def transactions_to_csv(transactions)
      CSV.generate do |csv|
        csv << %w[Date Description Note Wallet Category Type Amount]
        transactions.each do |t|
          type = t.transfer? ? 'transfer' : (t.income? ? 'income' : 'expense')
          csv << [
            t.transaction_date, t.title, t.note, t.wallet_name, t.category_name,
            type, format('%.2f', t.amount.to_f)
          ]
        end
      end
    end
  end
end
