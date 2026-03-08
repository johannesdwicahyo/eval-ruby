# frozen_string_literal: true

module EvalRuby
  module Metrics
    class PrecisionAtK < Base
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
