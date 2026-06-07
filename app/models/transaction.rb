# frozen_string_literal: true

module FinanceTracker
  # Parser model that wraps Transaction API envelopes.
  class Transaction
    def self.from_api(envelope)
      new(envelope)
    end

    def self.list_from_api(list)
      Array(list).map { |envelope| from_api(envelope) }
    end

    def initialize(envelope)
      root = envelope.is_a?(Hash) ? envelope : {}
      data = root['data'] || root[:data] || root
      data = {} unless data.is_a?(Hash)
      attrs = data['attributes'] || data[:attributes] || root['attributes'] || root[:attributes] || data
      attrs = {} unless attrs.is_a?(Hash)

      @id               = data['id'] || data[:id] || attrs['id'] || attrs[:id]
      @title            = attrs['title'] || attrs[:title]
      @amount           = attrs['amount'] || attrs[:amount]
      @transaction_date = attrs['transaction_date'] || attrs[:transaction_date]
      @note             = attrs['note'] || attrs[:note]
      @wallet_id        = attrs['wallet_id'] || attrs[:wallet_id]
      @category_id      = attrs['category_id'] || attrs[:category_id]
      @category_name    = attrs['category_name'] || attrs[:category_name]
    end

    attr_reader :id, :title, :amount, :transaction_date, :note,
                :wallet_id, :category_id, :category_name

    def [](key)
      send(key.to_s) rescue nil
    end

    def expense?
      amount.to_f.negative?
    end

    def income?
      !expense?
    end

    def display_amount
      value = amount.to_f
      format('%+.2f', value)
    end

    private_class_method :new
  end
end
