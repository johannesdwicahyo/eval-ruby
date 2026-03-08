# frozen_string_literal: true

require "eval_ruby"

module EvalRuby
  module RSpecMatchers
    class BeFaithfulTo
      def initialize(context)
        @context = Array(context)
        @threshold = 0.8
      end

      def with_threshold(threshold)
        @threshold = threshold
        self
      end

      def matches?(answer)
        @answer = answer
        judge = EvalRuby.send(:build_judge)
        result = Metrics::Faithfulness.new(judge: judge).call(answer: answer, context: @context)
        @score = result[:score]
        @score >= @threshold
      end

      def failure_message
        "expected answer to be faithful to context (threshold: #{@threshold}), but got score #{@score.round(4)}"
      end

      def failure_message_when_negated
        "expected answer not to be faithful to context, but got score #{@score.round(4)}"
      end
    end

    class HavePrecisionAtK
      def initialize(k)
        @k = k
        @threshold = 0.5
      end

      def above(threshold)
        @threshold = threshold
        self
      end

      def matches?(results)
        @results = results
        # results should respond to retrieved and relevant, or be arrays
        if results.is_a?(EvalRuby::RetrievalResult)
          @score = results.precision_at_k(@k)
        else
          raise ArgumentError, "Expected EvalRuby::RetrievalResult or use assert_precision_at_k"
        end
        @score >= @threshold
      end

      def failure_message
        "expected precision@#{@k} >= #{@threshold}, but got #{@score.round(4)}"
      end
    end

    def be_faithful_to(context)
      BeFaithfulTo.new(context)
    end

    def have_precision_at_k(k)
      HavePrecisionAtK.new(k)
    end
  end
end
