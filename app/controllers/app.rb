# frozen_string_literal: true

require 'rack/method_override'
require 'rack/session/pool'
require 'roda'
require 'slim'
require 'slim/include'
require_relative '../lib/secure_message'
require_relative '../lib/secure_session'
require_relative 'http_request'

module FinanceTracker
  # Base class for the FinanceTracker web app.
  class App < Roda
    rack_env = ENV.fetch('RACK_ENV', 'development')
    secure_scheme = ENV.fetch('SECURE_SCHEME', rack_env == 'production' ? 'HTTPS' : 'HTTP')

    session_secret = ENV['SESSION_SECRET'] ||
                     'development-session-secret-change-me-please-use-at-least-sixty-four-chars'
    raise Roda::RodaError, 'SESSION_SECRET must be at least 64 characters' if session_secret.length < 64
    SecureMessage.setup(ENV.fetch('MSG_KEY', session_secret))

    use Rack::MethodOverride
    if %w[development test].include?(rack_env)
      use Rack::Session::Pool,
          key: 'fintrack.session',
          expire_after: 2_592_000,
          httponly: true
    elsif rack_env == 'production'
      require 'rack/session/redis'

      redis_url = ENV.fetch('REDIS_URL', nil)
      raise Roda::RodaError, 'REDIS_URL must be configured in production' unless redis_url

      use Rack::Session::Redis,
          redis_server: redis_url,
          key: 'fintrack.session',
          expire_after: 2_592_000,
          secure: true,
          httponly: true
    end

    plugin :render, engine: 'slim', views: 'app/presentation/views'
    plugin :assets, css: 'style.css', path: 'app/presentation/assets'
    plugin :public, root: 'app/presentation/public'
    plugin :multi_route
    plugin :flash
    plugin :all_verbs

    route do |routing|
      response['Content-Type'] = 'text/html; charset=utf-8'
      request = HttpRequest.new(routing, secure_scheme: secure_scheme)
      if secure_scheme.casecmp('HTTPS').zero?
        routing.redirect(request.https_url, 301) unless request.secure?
        response['Strict-Transport-Security'] = 'max-age=31536000; includeSubDomains'
      end
      @current_account = SecureSession.get(session, 'current_account')

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