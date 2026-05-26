# frozen_string_literal: true

module FinanceTracker
  # Parser model that wraps Transaction API envelopes.
  # Use Transaction.from_api(envelope_hash) — `new` is private so the named
  # factory is the only entry point and the parsing role stays explicit.
  class Transaction
    attr_reader :id, :attributes

    def self.from_api(envelope)
      new(envelope)
    end

    def self.list_from_api(list)
      Array(list).map { |envelope| from_api(envelope) }
    end

    # rubocop:disable Metrics/AbcSize
    def initialize(envelope)
      root = envelope.is_a?(Hash) ? envelope : {}
      data = root['data'] || root[:data] || root
      data = {} unless data.is_a?(Hash)

      attrs = data['attributes'] || data[:attributes] || root['attributes'] || root[:attributes] || data
      attrs = {} unless attrs.is_a?(Hash)

      @id = data['id'] || data[:id] || attrs['id'] || attrs[:id]
      @attributes = attrs
    end
    # rubocop:enable Metrics/AbcSize

    def [](key)
      k = key.to_s
      @attributes[k] || @attributes[key.to_sym]
    end

    private_class_method :new
  end
end
