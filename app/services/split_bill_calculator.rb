# frozen_string_literal: true

require 'bigdecimal'
require 'bigdecimal/util'

module FinanceTracker
  module Services
    class SplitBillCalculator
      class InvalidInput < StandardError; end

      def call(subtotal:, participants_text:, tax: nil, tip: nil)
        subtotal_amount = parse_money(subtotal, 'Subtotal')
        tax_amount = parse_optional_money(tax, 'Tax')
        tip_amount = parse_optional_money(tip, 'Tip')
        participants = parse_participants(participants_text)

        total = subtotal_amount + tax_amount + tip_amount
        weights_sum = participants.sum { |entry| entry[:weight] }

        allocations = allocate(total, participants, weights_sum)

        {
          subtotal: money(subtotal_amount),
          tax: money(tax_amount),
          tip: money(tip_amount),
          total: money(total),
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

      def parse_optional_money(raw_value, label)
        stripped = raw_value.to_s.strip
        return BigDecimal('0') if stripped.empty?

        parse_money(stripped, label)
      end

      def parse_participants(participants_text)
        rows = participants_text.to_s.split(/[\n,;]/).map(&:strip).reject(&:empty?)
        raise InvalidInput, 'At least two participants are required' if rows.length < 2

        rows.map do |row|
          name, raw_weight = row.split(':', 2).map { |piece| piece.to_s.strip }
          raise InvalidInput, 'Participant name is required' if name.empty?

          weight = raw_weight.empty? ? BigDecimal('1') : BigDecimal(raw_weight)
          raise InvalidInput, "Weight for #{name} must be greater than zero" unless weight.positive?

          { name: name, weight: weight }
        rescue ArgumentError
          raise InvalidInput, "Weight for #{name} must be a valid number"
        end
      end

      def allocate(total, participants, weights_sum)
        remaining = total

        participants.each_with_index.map do |entry, index|
          amount =
            if index == participants.length - 1
              remaining
            else
              (total * entry[:weight] / weights_sum).round(2)
            end
          remaining -= amount

          {
            name: entry[:name],
            weight: entry[:weight].to_s('F'),
            amount: money(amount)
          }
        end
      end

      def money(value)
        value.round(2).to_s('F')
      end
    end
  end
end