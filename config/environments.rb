# frozen_string_literal: true

require 'roda'
require 'figaro'
require 'logger'
require 'openssl'
require 'rack/session'
require 'rack/session/redis'
require_relative '../require_app'

require_app('lib')

module FinanceTracker
  class App < Roda
    plugin :environments

    Figaro.application = Figaro::Application.new(
      environment: environment,
      path: File.expand_path('config/secrets.yml')
    )
    Figaro.load
    def self.config = Figaro.env

    # HTTP Request logging
    configure :development, :production do
      plugin :common_logger, $stdout
    end

    # Custom events logging
    LOGGER = Logger.new($stderr)
    def self.logger = LOGGER

    # Session configuration
    ONE_MONTH = 30 * 24 * 60 * 60

    @redis_url = ENV.delete('REDISCLOUD_URL') || ENV.delete('REDIS_URL')
    @redis_server =
      if @redis_url&.start_with?('rediss://')
        { url: @redis_url, ssl_params: { verify_mode: OpenSSL::SSL::VERIFY_NONE } }
      else
        @redis_url
      end

    SecureMessage.setup(ENV.delete('MSG_KEY'))
    SignedMessage.setup(ENV.delete('SIGNING_KEY')) # signs unauthenticated API requests
    SecureSession.setup(@redis_server) # used by `rake session:wipe`

    configure :development, :test do
      # Suppresses log info/warning outputs in dev/test environments
      logger.level = Logger::ERROR

      # Session cookie hardening: httponly blocks XSS exfiltration via document.cookie;
      # SameSite=Lax stops cross-site requests from carrying the session (CSRF mitigation).
      # No `secure:` in dev/test — rack-session refuses to commit a Secure cookie over
      # plain HTTP, which would break http://localhost logins.
      use Rack::Session::Pool,
          expire_after: ONE_MONTH,
          httponly: true,
          same_site: :lax
      require 'pry'

      def self.reload!
        exec 'pry -r ./spec/test_load_all'
      end
    end

    configure :production do
      plugin :redirect_http_to_https
      plugin :hsts

      # Production: add Secure so the cookie is TLS-only (always behind HTTPS on Heroku).
      use Rack::Session::Redis,
          expire_after: ONE_MONTH,
          redis_server: @redis_server,
          secure: true,
          httponly: true,
          same_site: :lax
    end
  end
end
