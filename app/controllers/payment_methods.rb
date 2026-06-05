# frozen_string_literal: true

require_relative 'app'
require_relative '../forms/form_base'
require_relative '../forms/create_payment_method'
require_relative '../services/list_payment_methods'
require_relative '../services/create_payment_method'

module FinanceTracker
  # Payment method pages and actions.
  class App < Roda
    route('payment-methods') do |routing|
      require_login!(routing)
      current_sess = FinanceTracker::CurrentSession.new(session)
      auth_token = current_sess.auth_token
      account_api_token = current_sess.account_api_token
      can_create_payment_method = @current_account.can_create_wallet?

      # GET /payment-methods/new
      routing.is 'new' do
        view 'payment_methods/new', locals: { can_create_payment_method: can_create_payment_method }
      end

      routing.is do
        # GET /payment-methods
        routing.get do
          payment_methods = FinanceTracker::Services::ListPaymentMethods.new.call(
            auth_token: auth_token,
            account_api_token: account_api_token
          )
          view 'payment_methods/index', locals: {
            payment_methods: payment_methods,
            can_create_payment_method: can_create_payment_method
          }
        rescue StandardError => e
          flash[:error] = "Could not load payment methods: #{e.message}"
          view 'payment_methods/index', locals: {
            payment_methods: [],
            can_create_payment_method: can_create_payment_method
          }
        end

        # POST /payment-methods
        routing.post do
          validation = FinanceTracker::Form::CreatePaymentMethod.call(routing.params)
          if validation.failure?
            flash[:error] = FinanceTracker::Form.validation_errors(validation)
            routing.redirect '/payment-methods/new'
          end

          FinanceTracker::Services::CreatePaymentMethod.new.call(
            auth_token: auth_token,
            name: validation[:name],
            method_type: validation[:method_type],
            account_number: validation[:account_number],
            balance: validation[:balance],
            account_api_token: account_api_token
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



