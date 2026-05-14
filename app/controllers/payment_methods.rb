# frozen_string_literal: true

require_relative 'app'
require_relative '../services/list_payment_methods'
require_relative '../services/create_payment_method'

module FinanceTracker
  # Payment method pages and actions.
  class App < Roda
    route('payment-methods') do |routing|
      require_login!(routing)
      current_account_id = @current_account['id']

      # GET /payment-methods/new
      routing.is 'new' do
        view 'payment_methods/new'
      end

      routing.is do
        # GET /payment-methods
        routing.get do
          payment_methods = FinanceTracker::Services::ListPaymentMethods.new.call(
            current_account_id: current_account_id
          )
          view 'payment_methods/index', locals: { payment_methods: payment_methods }
        rescue StandardError => e
          flash[:error] = "Could not load payment methods: #{e.message}"
          view 'payment_methods/index', locals: { payment_methods: [] }
        end

        # POST /payment-methods
        routing.post do
          FinanceTracker::Services::CreatePaymentMethod.new.call(
            current_account_id: current_account_id,
            name: routing.params['name'],
            method_type: routing.params['method_type'],
            account_number: routing.params['account_number'],
            balance: routing.params['balance']
          )
          flash[:notice] = 'Payment method created'
          routing.redirect '/payment-methods'
        rescue StandardError => e
          flash[:error] = "Could not create payment method: #{e.message}"
          routing.redirect '/payment-methods/new'
        end
      end
    end
  end
end
