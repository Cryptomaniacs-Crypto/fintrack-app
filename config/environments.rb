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

    @redis_url = ENV['REDISCLOUD_URL'] || ENV.fetch('REDIS_URL', nil)
    @redis_server =
      if @redis_url&.start_with?('rediss://')
        { url: @redis_url, ssl_params: { verify_mode: OpenSSL::SSL::VERIFY_NONE } }
      else
        @redis_url
      end

    SecureMessage.setup(ENV.fetch('MSG_KEY', nil))
    SignedMessage.setup(ENV.fetch('SIGNING_KEY', nil)) # signs unauthenticated API requests
    SecureSession.setup(@redis_server) # used by `rake session:wipe`

    configure :development, :test do
      # Suppresses log info/warning outputs in dev/test environments
      logger.level = Logger::ERROR

      use Rack::Session::Pool,
          expire_after: ONE_MONTH
      require 'pry'

      def self.reload!
        exec 'pry -r ./spec/test_load_all'
      end
    end

    configure :production do
      # round-trip.
      plugin :redirect_http_to_https
      plugin :hsts

      use Rack::Session::Redis,
          expire_after: ONE_MONTH,
          redis_server: @redis_server
    end
  end
end
