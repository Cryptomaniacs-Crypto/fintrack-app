# frozen_string_literal: true

module FinanceTracker
  class PaymentMethod
    attr_reader :id, :name, :method_type, :account_number, :balance

    def self.from_api(envelope)
      new(envelope)
    end

    def self.list_from_api(list)
      Array(list).map { |envelope| from_api(envelope) }
    end

    # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity
    def initialize(envelope)
      data = if envelope.is_a?(Hash)
               envelope['data'] || envelope[:data] || envelope
             else
               {}
             end

      attrs = if data.is_a?(Hash)
                data['attributes'] || data[:attributes] || data
              else
                {}
              end

      @id = data['id'] || data[:id] || attrs['id'] || attrs[:id]
      @name = attrs['name'] || attrs[:name]
      @method_type = attrs['method_type'] || attrs[:method_type]
      @account_number = attrs['account_number'] || attrs[:account_number]
      @balance = attrs['balance'] || attrs[:balance]
      @policies = envelope.is_a?(Hash) ? (envelope['policies'] || envelope[:policies] || {}) : {}
    end
    # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity

    def can_view?   = @policies['can_view']   || @policies[:can_view]   || false
    def can_edit?   = @policies['can_edit']   || @policies[:can_edit]   || false
    def can_delete? = @policies['can_delete'] || @policies[:can_delete] || false

    private_class_method :new
  end
end
