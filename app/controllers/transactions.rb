# frozen_string_literal: true

require_relative 'app'
require_relative '../services/list_transactions'

module FinanceTracker
  # Transaction pages.
  class App < Roda
    route('transactions') do |routing|
      require_login!(routing)
      current_account_id = @current_account['id']

      routing.is do
        # GET /transactions
        routing.get do
          transactions = FinanceTracker::Services::ListTransactions.new.call(
            current_account_id: current_account_id
          )
          view 'transactions/index', locals: { transactions: transactions }
        rescue StandardError => e
          flash[:error] = "Could not load transactions: #{e.message}"
          view 'transactions/index', locals: { transactions: [] }
        end
      end
    end
  end
end
