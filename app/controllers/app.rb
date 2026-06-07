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
        if @current_account&.username
          routing.redirect "/account/#{@current_account.username}"
        else
          routing.redirect '/auth/login'
        end
      end

      routing.on 'split-bill' do
        require_login!(routing)

        routing.get do
          defaults = {
            tax_percent: '',
            service_percent: '',
            participants: [
              { 'name' => '', 'amount' => '' }
            ]
          }
          view 'split_bill', locals: { result: nil, form_values: defaults }
        end

        routing.post do
          raw_participants = routing.params['participants']
          participants =
            if raw_participants.is_a?(Array)
              raw_participants.map do |row|
                {
                  'name' => row['name'].to_s,
                  'amount' => row['amount'].to_s
                }
              end
            else
              raw_participants.to_s.split(/\n/).map do |row|
                name, amount = row.split(':', 2)
                { 'name' => name.to_s, 'amount' => amount.to_s }
              end
            end

          form_values = {
            tax_percent: routing.params['tax_percent'].to_s,
            service_percent: routing.params['service_percent'].to_s,
            participants: participants
          }

          result = FinanceTracker::Services::SplitBillCalculator.new.call(
            participants_text: form_values[:participants],
            tax_percent: form_values[:tax_percent],
            service_percent: form_values[:service_percent]
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
      return if @current_account&.username

      flash[:error] = 'Please log in to continue'
      routing.redirect '/auth/login'
    end
  end
end
