# frozen_string_literal: true

require 'rack/method_override'
require 'roda'
require 'slim'
require 'slim/include'

module FinanceTracker
  # Base class for the FinanceTracker web app.
  class App < Roda
    session_secret = ENV['SESSION_SECRET'] ||
                     'development-session-secret-change-me-please-use-at-least-sixty-four-chars'
    raise Roda::RodaError, 'SESSION_SECRET must be at least 64 characters' if session_secret.length < 64

    use Rack::MethodOverride

    plugin :render, engine: 'slim', views: 'app/presentation/views'
    plugin :assets, css: 'style.css', path: 'app/presentation/assets'
    plugin :public, root: 'app/presentation/public'
    plugin :multi_route
    plugin :flash
    plugin :all_verbs
    plugin :sessions, secret: session_secret

    route do |routing|
      response['Content-Type'] = 'text/html; charset=utf-8'
      @current_account = session['current_account']
      
      # Debug logging
      puts "DEBUG: session keys = #{session.keys.inspect}"
      puts "DEBUG: @current_account = #{@current_account.inspect}"

      routing.public
      routing.assets
      routing.multi_route

      # GET /
      routing.root do
        view 'home', locals: { current_account: @current_account }
      end
    end

    private

    def system_admin?
      Array(@current_account['system_roles']).include?('admin')
    end

    def require_login!(routing)
      return if @current_account

      flash[:error] = 'Please log in to continue'
      routing.redirect '/auth/login'
    end
  end
end