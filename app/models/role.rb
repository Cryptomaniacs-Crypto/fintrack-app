# frozen_string_literal: true

module FinanceTracker
  # App-side wrapper for a system role returned by the API.
  # Accepts either a Hash ({id, name}) or a bare string role name.
  class Role
    def self.from_api(role_info)
      new(role_info)
    end

    def self.list_from_api(api_response)
      source = api_response.is_a?(Hash) ? (api_response['data'] || api_response.values.first || []) : api_response
      Array(source).map { |entry| new(entry) }
    end

    def initialize(role_info)
      @role_info = role_info
    end

    def id
      hash_source['id'] || hash_source[:id]
    end

    def name
      return @role_info if @role_info.is_a?(String)

      hash_source['name'] || hash_source[:name]
    end

    def to_s = name.to_s
    def to_h = @role_info.is_a?(Hash) ? @role_info : { 'name' => name }

    private

    def hash_source
      @role_info.is_a?(Hash) ? @role_info : {}
    end
  end
end
