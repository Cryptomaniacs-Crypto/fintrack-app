# frozen_string_literal: true

require 'rack/method_override'
require 'roda'
require 'slim'
require 'slim/include'
require_relative '../lib/secure_session'
require_relative '../services/split_bill_calculator'

module FinanceTracker
  # Base class for the FinanceTracker web app.
  class App < Roda
    use Rack::MethodOverride

    plugin :render, engine: 'slim', views: 'app/presentation/views'
    plugin :assets, css: 'style.css', path: 'app/presentation/assets'
    plugin :public, root: 'app/presentation/public'
    plugin :multi_route
    plugin :sessions, secret: (ENV['SESSION_SECRET'] || App.config.SESSION_SECRET)
    plugin :flash
    plugin :all_verbs

    route do |routing|
      routing.redirect_http_to_https if App.environment == :production

      response['Content-Type'] = 'text/html; charset=utf-8'
      @current_account = FinanceTracker::Account.from_api(SecureSession.get(session, 'current_account'))

      routing.public
      routing.assets
      routing.multi_route

      # GET /
      routing.root do
        view 'home', locals: { current_account: @current_account }
      end

      routing.on 'split-bill' do
        require_login!(routing)

        routing.get do
          defaults = {
            subtotal: '',
            tax: '',
            tip: '',
            participants: "Alice\nBob"
          }
          view 'split_bill', locals: { result: nil, form_values: defaults }
        end

        routing.post do
          form_values = {
            subtotal: routing.params['subtotal'].to_s,
            tax: routing.params['tax'].to_s,
            tip: routing.params['tip'].to_s,
            participants: routing.params['participants'].to_s
          }

          result = FinanceTracker::Services::SplitBillCalculator.new.call(
            subtotal: form_values[:subtotal],
            tax: form_values[:tax],
            tip: form_values[:tip],
            participants_text: form_values[:participants]
          )

          view 'split_bill', locals: { result: result, form_values: form_values }
        rescue FinanceTracker::Services::SplitBillCalculator::InvalidInput => e
          flash.now[:error] = e.message
          view 'split_bill', locals: { result: nil, form_values: form_values }
        end
      end
    end

    private

    def system_admin?(current_account = nil)
      account = current_account || @current_account
      capabilities = account&.dig('capabilities') || {}
      return true if capabilities['is_admin']

      Array(account&.dig('system_roles')).include?('admin')
    end

    def require_login!(routing)
      return if @current_account

      flash[:error] = 'Please log in to continue'
      routing.redirect '/auth/login'
    end
  end
end
