# frozen_string_literal: true

module EvalRuby
  module Metrics
    # Computes Mean Reciprocal Rank: 1/(position of first relevant document).
    #
    # @example
    #   MRR.new.call(retrieved: ["a", "b", "c"], relevant: ["b"])
    #   # => 0.5
    class MRR < Base
      # @param retrieved [Array<String>] retrieved document IDs in ranked order
      # @param relevant [Array<String>] ground-truth relevant document IDs
      # @return [Float] reciprocal rank (0.0-1.0)
      def call(retrieved:, relevant:, **_kwargs)
        retrieved.each_with_index do |doc, i|
          return 1.0 / (i + 1) if relevant.include?(doc)
        end
        0.0
      end
    end
  end
end
