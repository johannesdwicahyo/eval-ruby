# frozen_string_literal: true

require "eval_ruby"

module EvalRuby
  module RSpecMatchers
    # RSpec matcher that checks if an answer is faithful to the given context.
    #
    # @example
    #   expect(answer).to be_faithful_to(context)
    #   expect(answer).to be_faithful_to(context).with_threshold(0.9)
    class BeFaithfulTo
      def initialize(context, judge: nil)
        @context = Array(context)
        @threshold = 0.8
        @judge = judge
      end

      # @param threshold [Float] minimum faithfulness score (0.0 - 1.0)
      # @return [self]
      def with_threshold(threshold)
        @threshold = threshold
        self
      end

      # @param answer [String] the LLM-generated answer to evaluate
      # @return [Boolean]
      def matches?(answer)
        @answer = answer
        j = @judge || EvalRuby.send(:default_judge)
        result = Metrics::Faithfulness.new(judge: j).call(answer: answer, context: @context)
        @score = result[:score]
        @score >= @threshold
      end

      # @return [String]
      def failure_message
        "expected answer to be faithful to context (threshold: #{@threshold}), but got score #{@score.round(4)}"
      end

      # @return [String]
      def failure_message_when_negated
        "expected answer not to be faithful to context, but got score #{@score.round(4)}"
      end
    end

    # RSpec matcher that checks precision@k for retrieval results.
    #
    # @example
    #   expect(retrieval_result).to have_precision_at_k(5).above(0.8)
    class HavePrecisionAtK
      def initialize(k)
        @k = k
        @threshold = 0.5
      end

      # @param threshold [Float] minimum precision score (0.0 - 1.0)
      # @return [self]
      def above(threshold)
        @threshold = threshold
        self
      end

      # @param results [EvalRuby::RetrievalResult]
      # @return [Boolean]
      def matches?(results)
        @results = results
        if results.is_a?(EvalRuby::RetrievalResult)
          @score = results.precision_at_k(@k)
        else
          raise ArgumentError, "Expected EvalRuby::RetrievalResult or use assert_precision_at_k"
        end
        @score >= @threshold
      end

      # @return [String]
      def failure_message
        "expected precision@#{@k} >= #{@threshold}, but got #{@score.round(4)}"
      end
    end

    # @param context [Array<String>, String] context to check faithfulness against
    # @param judge [EvalRuby::Judges::Base, nil] optional judge (uses configured default if nil)
    # @return [BeFaithfulTo]
    def be_faithful_to(context, judge: nil)
      BeFaithfulTo.new(context, judge: judge)
    end

    # @param k [Integer] number of top results to evaluate
    # @return [HavePrecisionAtK]
    def have_precision_at_k(k)
      HavePrecisionAtK.new(k)
    end
  end

  class << self
    private

    # Build a judge from the current configuration.
    # @return [EvalRuby::Judges::Base]
    def default_judge
      case configuration.judge_llm
      when :openai
        Judges::OpenAI.new(configuration)
      when :anthropic
        Judges::Anthropic.new(configuration)
      else
        raise Error, "Unknown judge LLM: #{configuration.judge_llm}"
      end
    end
  end
end
