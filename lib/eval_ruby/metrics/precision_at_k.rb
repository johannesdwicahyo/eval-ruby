# frozen_string_literal: true

module EvalRuby
  module Metrics
    # Computes Precision@K: the fraction of top-k retrieved documents that are relevant.
    #
    # @example
    #   PrecisionAtK.new.call(retrieved: ["a", "b", "c"], relevant: ["a", "c"], k: 3)
    #   # => 0.667
    class PrecisionAtK < Base
      # @param retrieved [Array<String>] retrieved document IDs in ranked order
      # @param relevant [Array<String>] ground-truth relevant document IDs
      # @param k [Integer, nil] number of top results (nil for all)
      # @return [Float] precision score (0.0-1.0)
      def call(retrieved:, relevant:, k: nil, **_kwargs)
        k ||= retrieved.length
        top_k = retrieved.first(k)
        return 0.0 if top_k.empty?

        hits = top_k.count { |doc| relevant.include?(doc) }
        hits.to_f / top_k.size
      end
    end
  end
end
