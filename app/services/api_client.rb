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
        @base_url = if config.respond_to?(:API_URL)
                      config.API_URL
                    elsif config.is_a?(Hash)
                      config[:API_URL] || config['API_URL'] || base_url
                    else
                      base_url
                    end
      end

      def get(path, params: {})
        full_path = params.empty? ? path : "#{path}?#{URI.encode_www_form(params)}"
        parse(HTTP.get(url(full_path)))
      end

      def post(path, body)
        parse(HTTP.post(url(path), json: body))
      end

      def put(path, body)
        parse(HTTP.put(url(path), json: body))
      end

      def delete(path, body = nil)
        request = HTTP.headers('Content-Type' => 'application/json')
        response = body ? request.delete(url(path), body: body.to_json) : request.delete(url(path))
        parse(response)
      end

      def authenticated_post(path, body, current_account_id:)
        post(path, body.merge(current_account_id: current_account_id))
      end

      def authenticated_put(path, body, current_account_id:)
        put(path, body.merge(current_account_id: current_account_id))
      end

      def authenticated_delete(path, current_account_id:)
        delete(path, { current_account_id: current_account_id })
      end

      private

      def url(path)
        "#{@base_url}#{path}"
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