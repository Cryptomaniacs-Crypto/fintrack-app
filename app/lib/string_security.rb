# frozen_string_literal: true

module FinanceTracker
  # Shannon-entropy estimator for password strength validation.
  # Rejects weak-but-long passwords (e.g. "aaaaaaaa" has entropy < 1.0).
  module StringSecurity
    module_function

    def entropy(string)
      return 0.0 if string.nil? || string.empty?

      counts = string.each_char.tally
      length = string.length.to_f
      counts.values.sum do |count|
        probability = count / length
        -probability * Math.log2(probability)
      end
    end
  end
end
