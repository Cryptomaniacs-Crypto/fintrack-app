# frozen_string_literal: true

require 'json'
require 'net/http'
require 'uri'

module FinanceTracker
  module Services
    class AccountApi
      class ApiError < StandardError; end

      def initialize(base_url: ENV.fetch('FINTRACK_API_URL', 'http://localhost:9292'))
        @base_url = base_url
      end

      def fetch_account(username:, current_account_id:)
        uri = build_uri("/api/v1/accounts/#{username}", current_account_id: current_account_id)
        response = Net::HTTP.get_response(uri)
        parse_account_response(response)
      end

      def grant_system_role(current_account_id:, target_username:, role_name:)
        request_role_change(
          :put,
          target_username: target_username,
          role_name: role_name,
          current_account_id: current_account_id
        )
      end

      def revoke_system_role(current_account_id:, target_username:, role_name:)
        request_role_change(
          :delete,
          target_username: target_username,
          role_name: role_name,
          current_account_id: current_account_id
        )
      end

      private

      def request_role_change(method, target_username:, role_name:, current_account_id:)
        uri = build_uri("/api/v1/accounts/#{target_username}/system_roles/#{role_name}")
        request = Net::HTTP.const_get(method.to_s.capitalize).new(uri)
        request['Content-Type'] = 'application/json'
        request.body = JSON.generate(current_account_id: current_account_id)

        response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https') do |http|
          http.request(request)
        end

        parse_api_response(response)
      end

      def build_uri(path, current_account_id: nil)
        uri = URI.join(@base_url, path)
        uri.query = URI.encode_www_form(current_account_id: current_account_id) if current_account_id
        uri
      end

      def parse_account_response(response)
        parsed = parse_api_response(response)
        body = parsed.is_a?(Hash) ? parsed : {}
        account = body['data'] || body
        attrs = account['attributes'] || account
        include_data = account['include'] || body['include'] || {}

        {
          'id' => attrs['id'] || attrs[:id],
          'username' => attrs['username'] || attrs[:username],
          'email' => attrs['email'] || attrs[:email],
          'system_roles' => Array(include_data['system_roles'] || include_data[:system_roles]).map(&:to_s)
        }.compact
      end

      def parse_api_response(response)
        body = response.body.to_s.strip

        case response
        when Net::HTTPSuccess, Net::HTTPCreated, Net::HTTPNoContent
          body.empty? ? {} : JSON.parse(body)
        else
          message = JSON.parse(body)['message'] rescue body
          message = message.to_s.strip
          raise ApiError, (message.empty? ? "API error #{response.code}" : message)
        end
      rescue JSON::ParserError
        raise ApiError, "API returned invalid JSON (status #{response.code})"
      end
    end
  end
end