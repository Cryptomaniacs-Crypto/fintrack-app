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
        @base_url = configured.to_s.empty? ? base_url : configured
      end

      def get(path, params: {}, headers: {})
        full_path = params.empty? ? path : "#{path}?#{URI.encode_www_form(params)}"
        parse(HTTP.headers(headers).get(url(full_path)))
      end

      def post(path, body, headers: {})
        parse(HTTP.headers(headers).post(url(path), json: body))
      end

      def put(path, body, headers: {})
        parse(HTTP.headers(headers).put(url(path), json: body))
      end

      def delete(path, body = nil, headers: {})
        request = HTTP.headers(headers)
        response = body ? request.delete(url(path), body: body.to_json) : request.delete(url(path))
        parse(response)
      end

      def authenticated_post(path, body, auth_token:)
        post(path, body, headers: auth_headers(auth_token))
      end

      def authenticated_put(path, body, auth_token:)
        put(path, body, headers: auth_headers(auth_token))
      end

      def authenticated_delete(path, auth_token:)
        delete(path, nil, headers: auth_headers(auth_token))
      end

      private

      def auth_headers(auth_token)
        return {} if auth_token.to_s.empty?

        { 'Authorization' => "Bearer #{auth_token}" }
      end

      def url(path)
        path_str = path.to_s
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