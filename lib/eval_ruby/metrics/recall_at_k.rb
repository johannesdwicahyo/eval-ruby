# frozen_string_literal: true

module EvalRuby
  module Metrics
    # Computes Recall@K: the fraction of relevant documents found in the top-k results.
    #
    # @example
    #   RecallAtK.new.call(retrieved: ["a", "b", "c"], relevant: ["a", "c"], k: 3)
    #   # => 1.0
    class RecallAtK < Base
      # @param retrieved [Array<String>] retrieved document IDs in ranked order
      # @param relevant [Array<String>] ground-truth relevant document IDs
      # @param k [Integer, nil] number of top results (nil for all)
      # @return [Float] recall score (0.0-1.0)
      def call(retrieved:, relevant:, k: nil, **_kwargs)
        return 0.0 if relevant.empty?

        k ||= retrieved.length
        top_k = retrieved.first(k)
        hits = top_k.count { |doc| relevant.include?(doc) }
        hits.to_f / relevant.size
      end
    end
  end
end
