# frozen_string_literal: true

require 'http'
require 'json'
require 'uri'

module FinanceTracker
  module Services
    class ApiClient
      class ApiError < StandardError
        attr_reader :status, :body

        def initialize(status, body)
          @status = status
          @body = body
          message = body.is_a?(Hash) ? body['message'].to_s : body.to_s
          super(message)
        end
      end

      def initialize(config = nil, base_url: ENV.fetch('FINTRACK_API_URL', 'http://localhost:9292'))
        configured = if config.respond_to?(:API_URL)
                       config.API_URL
                     elsif config.is_a?(Hash)
                       config[:API_URL] || config['API_URL']
                     end
        @base_url = (configured.to_s.empty? ? base_url : configured).to_s.chomp('/')
      end

      def get(path, params: {}, auth_token: nil, account_api_token: nil)
        full_path = params.empty? ? path : "#{path}?#{URI.encode_www_form(params)}"
        parse(http(auth_token: auth_token, account_api_token: account_api_token).get(url(full_path)))
      end

      def post(path, body, auth_token: nil, account_api_token: nil)
        parse(http(auth_token: auth_token, account_api_token: account_api_token).post(url(path), json: body))
      end

      def put(path, body, auth_token: nil, account_api_token: nil)
        parse(http(auth_token: auth_token, account_api_token: account_api_token).put(url(path), json: body))
      end

      def delete(path, body = nil, auth_token: nil, account_api_token: nil)
        request = http(auth_token: auth_token, account_api_token: account_api_token).headers('Content-Type' => 'application/json')
        response = body ? request.delete(url(path), body: body.to_json) : request.delete(url(path))
        parse(response)
      end

      private

      def http(auth_token: nil, account_api_token: nil)
        headers = {}
        token = auth_token.to_s
        headers['Authorization'] = "Bearer #{token}" unless token.empty?
        acct_token = account_api_token.to_s
        headers['Account-Api-Token'] = acct_token unless acct_token.empty?
        return HTTP if headers.empty?

        HTTP.headers(headers)
      end

      def url(path)
        path_str = path.to_s
        path_str = "/#{path_str}" unless path_str.start_with?('/')

        if @base_url.end_with?('/api/v1') && path_str.start_with?('/api/v1')
          path_str = path_str.sub(%r{\A/api/v1}, '')
        end

        "#{@base_url}#{path_str}"
      end

      def parse(response)
        raw = response.body.to_s
        parsed = raw.empty? ? {} : JSON.parse(raw)
        raise ApiError.new(response.code, parsed) unless (200..299).cover?(response.code)

        parsed
      rescue JSON::ParserError
        raise ApiError.new(response.code, { 'message' => 'API returned invalid JSON' })
      end
    end
  end
end