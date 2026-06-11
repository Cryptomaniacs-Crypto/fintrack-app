# frozen_string_literal: true

require 'json'
require 'net/http'
require 'uri'

require_relative '../models/account'

module FinanceTracker
  module Services
    class AccountApi
      class ApiError < StandardError; end

      def initialize(base_url: ENV.fetch('FINTRACK_API_URL', 'http://localhost:9292'))
        @base_url = base_url
      end

      def fetch_account(username:, auth_token:)
        uri = build_uri("/api/v1/accounts/#{username}")
        response = request_with_auth(uri, auth_token)
        parse_account_response(response)
      end

      def grant_system_role(auth_token:, target_username:, role_name:)
        request_role_change(
          :put,
          target_username: target_username,
          role_name: role_name,
          auth_token: auth_token
        )
      end

      def revoke_system_role(auth_token:, target_username:, role_name:)
        request_role_change(
          :delete,
          target_username: target_username,
          role_name: role_name,
          auth_token: auth_token
        )
      end

      private

      def request_role_change(method, target_username:, role_name:, auth_token:)
        uri = build_uri("/api/v1/accounts/#{target_username}/system_roles/#{role_name}")
        request = Net::HTTP.const_get(method.to_s.capitalize).new(uri)
        request['Content-Type'] = 'application/json'
        request['Authorization'] = "Bearer #{auth_token}"

        response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https') do |http|
          http.request(request)
        end

        parse_api_response(response)
      end

      def build_uri(path)
        URI.join(@base_url, path)
      end

      def request_with_auth(uri, auth_token)
        request = Net::HTTP::Get.new(uri)
        request['Authorization'] = "Bearer #{auth_token}"
        Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https') do |http|
          http.request(request)
        end
      end

      def parse_account_response(response)
        parsed = parse_api_response(response)

        FinanceTracker::Account.from_api(parsed).account_info
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