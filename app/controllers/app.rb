# frozen_string_literal: true

require 'date'
require 'json'
require 'rack/method_override'
require 'roda'
require 'slim'
require 'slim/include'
require_relative '../lib/secure_session'
require_relative '../models/current_session'
require_relative '../services/fintrack_api'
require_relative '../services/list_transactions'

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
      @current_account = SecureSession.get(session, 'current_account')

      routing.public
      routing.assets
      routing.multi_route

      # GET /
      routing.root do
        stats = {}
        if @current_account
          begin
            current_sess = FinanceTracker::CurrentSession.new(session)
            auth_token   = current_sess.auth_token
            txns         = FinanceTracker::Services::ListTransactions.new(App.config)
                             .call(auth_token: auth_token)
            stats        = build_dashboard_stats(txns)
          rescue StandardError
            stats = {}
          end
        end
        view 'home', locals: { current_account: @current_account, stats: stats }
      end
    end

    private

    def system_admin?(current_account = nil)
      account = current_account || @current_account
      Array(account&.dig('system_roles')).include?('admin')
    end

    def require_login!(routing)
      return if @current_account

      # Save the requested path so login can redirect back to it.
      intended = routing.env['PATH_INFO'].to_s
      intended += "?#{routing.env['QUERY_STRING']}" unless routing.env['QUERY_STRING'].to_s.empty?
      session['return_to'] = intended if intended.start_with?('/')

      flash[:error] = 'Please log in to continue'
      routing.redirect '/auth/login'
    end

    def build_dashboard_stats(transactions)
      today = Date.today

      month_txns = transactions.select { |t|
        d = (Date.parse(t.transaction_date.to_s) rescue nil)
        d && d.year == today.year && d.month == today.month
      }

      income   = month_txns.select(&:income?).sum  { |t| t.amount.to_f }
      expenses = month_txns.select(&:expense?).sum { |t| t.amount.to_f.abs }

      by_category = month_txns
        .select { |t| t.expense? && !t.title.to_s.start_with?('Transfer') }
        .group_by { |t| t.category_name.to_s.empty? ? 'Uncategorized' : t.category_name }
        .transform_values { |ts| ts.sum { |t| t.amount.to_f.abs }.round(2) }
        .sort_by { |_, v| -v }
        .to_h

      monthly = 5.downto(0).map { |i|
        d = today << i
        m = transactions.select { |t|
          dt = (Date.parse(t.transaction_date.to_s) rescue nil)
          dt && dt.year == d.year && dt.month == d.month
        }
        {
          label:    d.strftime('%b %y'),
          income:   m.select(&:income?).sum  { |t| t.amount.to_f }.round(2),
          expenses: m.select(&:expense?).sum { |t| t.amount.to_f.abs }.round(2)
        }
      }

      recent = transactions
        .sort_by { |t| (Date.parse(t.transaction_date.to_s) rescue Date.new(2000)) }
        .reverse
        .first(5)

      { income: income, expenses: expenses, net: income - expenses,
        by_category: by_category, monthly: monthly, recent: recent }
    end
  end
end
