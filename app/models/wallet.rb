# frozen_string_literal: true

module FinanceTracker
  class Wallet
    def self.from_api(wallet_info)
      new(wallet_info)
    end

    # Builds an array of Wallet objects from an /api/v1/wallets index response.
    # Accepts either a wrapped envelope ({"data" => [...]}) or a bare array.
    def self.list_from_api(api_response)
      Array(api_response.is_a?(Hash) ? api_response['data'] : api_response).map do |entry|
        new(entry)
      end
    end

    def initialize(wallet_info)
      @wallet_info = wallet_info || {}
    end

    def [](key)
      attributes[key.to_s] || attributes[key.to_sym] || @wallet_info[key.to_s] || @wallet_info[key.to_sym]
    end

    def id = attribute('id')
    def name = attribute('name')
    def account_number = attribute('account_number')
    def balance = attribute('balance')
    def policies = @wallet_info['policies'] || @wallet_info[:policies] || {}

    def can_view? = policies['can_view'] || policies[:can_view] || false
    def can_edit? = policies['can_edit'] || policies[:can_edit] || false
    def can_delete? = policies['can_delete'] || policies[:can_delete] || false

    private

    def attributes
      @wallet_info['data'] ? @wallet_info['data']['attributes'] : (@wallet_info['attributes'] || {})
    end

    def attribute(name)
      attributes[name] || attributes[name.to_sym]
    end
  end
end
