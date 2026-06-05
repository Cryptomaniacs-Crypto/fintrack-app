# frozen_string_literal: true

require 'http'
require 'json'

require_relative 'api_client'

module FinanceTracker
  module Services
    class AuthorizeGoogleAccount
      class AuthorizeError < StandardError; end

      def initialize(config = nil, google_token_url: ENV.fetch('GOOGLE_TOKEN_URL', 'https://oauth2.googleapis.com/token'))
        @client = ApiClient.new(config)
        @config = config
        @google_token_url = google_token_url
      end

      # Exchange the Google authorization `code` with the API which performs
      # the token exchange/validation and returns account/auth tokens.
      def call(code)
        id_token = exchange_code_for_id_token(code)
        @client.post('/api/v1/auth/sso', { id_token: id_token })
      rescue ApiClient::ApiError => e
        raise AuthorizeError, e.message
      end

      private

      def exchange_code_for_id_token(code)
        raise AuthorizeError, 'Missing Google authorization code' if code.to_s.strip.empty?

        response = HTTP.headers('Accept' => 'application/json').post(
          @google_token_url,
          form: {
            code: code,
            client_id: fetch_config('GOOGLE_CLIENT_ID'),
            client_secret: fetch_config('GOOGLE_CLIENT_SECRET'),
            redirect_uri: fetch_config('GOOGLE_REDIRECT_URI'),
            grant_type: 'authorization_code'
          }
        )

        parsed = JSON.parse(response.body.to_s)
        unless response.status.success?
          message = parsed['error_description'] || parsed['error'] || 'Google token exchange failed'
          raise AuthorizeError, message
        end

        id_token = parsed['id_token'].to_s
        raise AuthorizeError, 'Google token exchange did not return id_token' if id_token.empty?

        id_token
      rescue HTTP::Error => e
        raise AuthorizeError, "Google token exchange failed: #{e.message}"
      rescue JSON::ParserError
        raise AuthorizeError, 'Google token endpoint returned invalid JSON'
      end

      def fetch_config(key)
        value =
          if @config.respond_to?(key)
            @config.public_send(key)
          elsif @config.is_a?(Hash)
            @config[key] || @config[key.to_sym]
          else
            ENV[key]
          end

        raise AuthorizeError, "Missing configuration: #{key}" if value.to_s.strip.empty?

        value
      end
    end
  end
end
