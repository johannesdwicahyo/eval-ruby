# frozen_string_literal: true

module EvalRuby
  module Metrics
    class MRR < Base
      def call(retrieved:, relevant:, **_kwargs)
        retrieved.each_with_index do |doc, i|
          return 1.0 / (i + 1) if relevant.include?(doc)
        end
        0.0
      end
    end
  end
end
