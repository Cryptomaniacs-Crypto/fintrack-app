# frozen_string_literal: true

module FinanceTracker
  # App-side wrapper for a category returned by the API.
  class Category
    def self.from_api(category_info)
      new(category_info)
    end

    def self.list_from_api(api_response)
      Array(api_response.is_a?(Hash) ? api_response['data'] : api_response).map do |entry|
        new(entry)
      end
    end

    def initialize(category_info)
      @category_info = category_info || {}
    end

    def [](key)
      attribute(key.to_s) || @category_info[key.to_s] || @category_info[key.to_sym]
    end

    def id = attribute('id')
    def name = attribute('name')
    def description = attribute('description')
    def is_default? = attribute('is_default') == true || attribute('is_default') == 'true'

    def policies = @category_info['policies'] || @category_info[:policies] || {}

    def can_view? = policies['can_view'] || policies[:can_view] || false
    def can_edit? = policies['can_edit'] || policies[:can_edit] || false
    def can_delete? = policies['can_delete'] || policies[:can_delete] || false

    def to_h = @category_info

    private

    def attributes
      @category_info['data'] ? @category_info['data']['attributes'] : (@category_info['attributes'] || {})
    end

    def attribute(name)
      attributes[name] || attributes[name.to_sym]
    end
  end
end
