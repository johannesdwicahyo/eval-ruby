# frozen_string_literal: true

module EvalRuby
  module Metrics
    class RecallAtK < Base
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
