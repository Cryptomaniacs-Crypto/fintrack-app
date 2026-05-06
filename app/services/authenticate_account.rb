# frozen_string_literal: true

require 'json'
require 'net/http'
require 'uri'

module Fintrack
  module Services
    class AuthenticateAccount
      class AuthenticationFailed < StandardError; end
      class ApiUnavailable < StandardError; end

      def initialize(base_url: ENV.fetch('FINTRACK_API_URL', 'http://localhost:3000'),
                     auth_path: ENV.fetch('FINTRACK_API_AUTH_PATH', '/api/v1/auth/login'))
        @base_url = base_url
        @auth_path = auth_path
      end

      # Returns a non-sensitive account hash for session storage
      # Expected API response formats supported:
      # - { data: { attributes: { username:, email:, id: } } }
      # - { username:, email:, id: }
      def call(username:, password:)
        payload = { username: username.to_s.strip, password: password.to_s }
        raise AuthenticationFailed, 'Username and password required' if payload[:username].empty? || payload[:password].empty?

        uri = URI.join(@base_url, @auth_path)
        req = Net::HTTP::Post.new(uri)
        req['Content-Type'] = 'application/json'
        req.body = JSON.generate(payload)

        response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https') do |http|
          http.request(req)
        end

        case response
        when Net::HTTPSuccess
          account = parse_account(JSON.parse(response.body))
          unless account['username']
            raise AuthenticationFailed, 'Authentication response missing username'
          end
          account
        when Net::HTTPUnauthorized, Net::HTTPForbidden
          raise AuthenticationFailed, 'Username and password did not match our records'
        else
          raise AuthenticationFailed, "Authentication failed (status #{response.code})"
        end
      rescue AuthenticationFailed
        raise
      rescue StandardError => e
        raise ApiUnavailable, e.message
      end

      private

      def parse_account(body)
        attrs = body.dig('data', 'attributes') || body['attributes'] || body
        {
          'id' => attrs['id'] || attrs[:id],
          'username' => attrs['username'] || attrs[:username],
          'email' => attrs['email'] || attrs[:email]
        }.compact
      end
    end
  end
end
