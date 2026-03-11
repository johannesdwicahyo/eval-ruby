# frozen_string_literal: true

module EvalRuby
  module Metrics
    # Computes Normalized Discounted Cumulative Gain (NDCG).
    # Measures ranking quality by comparing actual ranking to ideal ranking.
    #
    # @example
    #   NDCG.new.call(retrieved: ["a", "b", "c"], relevant: ["a", "c"])
    #   # => 0.863
    class NDCG < Base
      # @param retrieved [Array<String>] retrieved document IDs in ranked order
      # @param relevant [Array<String>] ground-truth relevant document IDs
      # @param k [Integer, nil] number of top results (nil for all)
      # @return [Float] NDCG score (0.0-1.0)
      def call(retrieved:, relevant:, k: nil, **_kwargs)
        k ||= retrieved.length
        top_k = retrieved.first(k)

        dcg = top_k.each_with_index.sum do |doc, i|
          rel = relevant.include?(doc) ? 1.0 : 0.0
          rel / Math.log2(i + 2)
        end

        ideal_length = [relevant.length, k].min
        idcg = ideal_length.times.sum { |i| 1.0 / Math.log2(i + 2) }

        idcg.zero? ? 0.0 : dcg / idcg
      end
    end
  end
end
