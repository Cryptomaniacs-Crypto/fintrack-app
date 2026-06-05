# frozen_string_literal: true

require 'bigdecimal'
require 'bigdecimal/util'

module FinanceTracker
  module Services
    class SplitBillCalculator
      class InvalidInput < StandardError; end

      def call(participants_text:, tax_percent: nil, service_percent: nil)
        participants = parse_participants(participants_text)
        tax_rate = parse_percentage(tax_percent, 'Tax')
        service_rate = parse_percentage(service_percent, 'Service charge')

        allocations = participants.map do |entry|
          tax_amount = (entry[:amount] * tax_rate / 100).round(2)
          service_amount = (entry[:amount] * service_rate / 100).round(2)
          total = entry[:amount] + tax_amount + service_amount

          {
            name: entry[:name],
            amount: money(entry[:amount]),
            tax: money(tax_amount),
            service: money(service_amount),
            total: money(total)
          }
        end

        grand_amount = allocations.sum { |entry| BigDecimal(entry[:total]) }

        {
          tax_percent: money(tax_rate),
          service_percent: money(service_rate),
          grand_total: money(grand_amount),
          participants: allocations
        }
      end

      private

      def parse_money(raw_value, label)
        value = BigDecimal(raw_value.to_s)
        raise InvalidInput, "#{label} must be zero or greater" if value.negative?

        value
      rescue ArgumentError
        raise InvalidInput, "#{label} must be a valid number"
      end

      def parse_percentage(raw_value, label)
        stripped = raw_value.to_s.strip
        return BigDecimal('0') if stripped.empty?

        parse_money(stripped, label)
      end

      def parse_participants(participants_text)
        rows = participants_text.to_s.split(/[\n,;]/).map(&:strip).reject(&:empty?)
        raise InvalidInput, 'At least one person is required' if rows.empty?

        rows.map do |row|
          name, raw_amount = row.split(':', 2).map { |piece| piece.to_s.strip }
          raise InvalidInput, 'Participant name is required' if name.empty?
          raise InvalidInput, "Amount for #{name} is required" if raw_amount.empty?

          amount = parse_money(raw_amount, "Amount for #{name}")
          raise InvalidInput, "Amount for #{name} must be greater than zero" unless amount.positive?

          { name: name, amount: amount }
        rescue ArgumentError
          raise InvalidInput, "Amount for #{name} must be a valid number"
        end
      end

      def money(value)
        value.round(2).to_s('F')
      end
    end
  end
end