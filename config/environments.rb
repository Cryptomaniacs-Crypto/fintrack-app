# frozen_string_literal: true

require 'logger'
require 'roda'
require 'figaro'
require 'rack/session/cookie'

module FinTrack
  # Web app for the FinTrack API
  class App < Roda
    plugin :environments

    # rubocop:disable Lint/ConstantDefinitionInBlock
    configure do
      Figaro.application = Figaro::Application.new(
        environment: environment,
        path: File.expand_path('config/secrets.yml')
      )
      Figaro.load

      def self.config = Figaro.env

      LOGGER = Logger.new($stderr)
      def self.logger = LOGGER

      use Rack::Session::Cookie,
          secret: config.SESSION_SECRET,
          key: 'fintrack.session',
          expire_after: 60 * 60 * 24 * 30 # 30 days
    end
    # rubocop:enable Lint/ConstantDefinitionInBlock

    configure :development, :test do
      require 'pry'
    end
  end
end
