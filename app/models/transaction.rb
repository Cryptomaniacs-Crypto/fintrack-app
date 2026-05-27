# frozen_string_literal: true

module FinanceTracker
  # App-side wrapper for a transaction returned by the API.
  # Owns all knowledge of the API JSON shape so callers don't index into raw hashes.
  class Transaction
    def self.from_api(transaction_info)
      new(transaction_info)
    end

    def self.list_from_api(api_response)
      Array(api_response.is_a?(Hash) ? api_response['data'] : api_response).map do |entry|
        new(entry)
      end
    end

    def initialize(transaction_info)
      @transaction_info = transaction_info || {}
    end

    def [](key)
      attribute(key.to_s) || @transaction_info[key.to_s] || @transaction_info[key.to_sym]
    end

    def id = attribute('id')
    def title = attribute('title')
    def amount = attribute('amount')
    def transaction_date = attribute('transaction_date')
    def note = attribute('note')
    def wallet_id = attribute('wallet_id')
    def category_id = attribute('category_id')

    def policies = @transaction_info['policies'] || @transaction_info[:policies] || {}

    def can_view? = policies['can_view'] || policies[:can_view] || false
    def can_edit? = policies['can_edit'] || policies[:can_edit] || false
    def can_delete? = policies['can_delete'] || policies[:can_delete] || false

    def to_h = @transaction_info

    private

    def attributes
      @transaction_info['data'] ? @transaction_info['data']['attributes'] : (@transaction_info['attributes'] || {})
    end

    def attribute(name)
      attributes[name] || attributes[name.to_sym]
    end
  end
end
