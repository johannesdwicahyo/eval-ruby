# frozen_string_literal: true

require "eval_ruby"

module EvalRuby
  module Assertions
    def assert_faithful(answer, context, threshold: 0.8, message: nil)
      result = eval_metric(:faithfulness, answer: answer, context: Array(context))
      msg = message || "Expected faithfulness >= #{threshold}, got #{result[:score].round(4)}"
      assert result[:score] >= threshold, msg
    end

    def assert_relevant(question, answer, threshold: 0.8, message: nil)
      result = eval_metric(:relevance, question: question, answer: answer)
      msg = message || "Expected relevance >= #{threshold}, got #{result[:score].round(4)}"
      assert result[:score] >= threshold, msg
    end

    def assert_correct(answer, ground_truth:, threshold: 0.7, message: nil)
      result = eval_metric(:correctness, answer: answer, ground_truth: ground_truth)
      msg = message || "Expected correctness >= #{threshold}, got #{result[:score].round(4)}"
      assert result[:score] >= threshold, msg
    end

    def assert_precision_at_k(retrieved, relevant, k:, threshold: 0.5, message: nil)
      score = Metrics::PrecisionAtK.new.call(retrieved: retrieved, relevant: relevant, k: k)
      msg = message || "Expected precision@#{k} >= #{threshold}, got #{score.round(4)}"
      assert score >= threshold, msg
    end

    def refute_hallucination(answer, context, threshold: 0.8, message: nil)
      result = eval_metric(:faithfulness, answer: answer, context: Array(context))
      msg = message || "Expected no hallucination (faithfulness >= #{threshold}), got #{result[:score].round(4)}"
      assert result[:score] >= threshold, msg
    end

    private

    def eval_metric(metric_name, **kwargs)
      judge = EvalRuby.send(:build_judge)
      metric_class = case metric_name
      when :faithfulness then Metrics::Faithfulness
      when :relevance then Metrics::Relevance
      when :correctness then Metrics::Correctness
      when :context_precision then Metrics::ContextPrecision
      when :context_recall then Metrics::ContextRecall
      end
      metric_class.new(judge: judge).call(**kwargs)
    end
  end
end
