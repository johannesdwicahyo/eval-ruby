# frozen_string_literal: true

require_relative "eval_ruby/version"
require_relative "eval_ruby/configuration"
require_relative "eval_ruby/judges/base"
require_relative "eval_ruby/judges/openai"
require_relative "eval_ruby/judges/anthropic"
require_relative "eval_ruby/metrics/base"
require_relative "eval_ruby/metrics/faithfulness"
require_relative "eval_ruby/metrics/relevance"
require_relative "eval_ruby/metrics/correctness"
require_relative "eval_ruby/metrics/context_precision"
require_relative "eval_ruby/metrics/context_recall"
require_relative "eval_ruby/metrics/precision_at_k"
require_relative "eval_ruby/metrics/recall_at_k"
require_relative "eval_ruby/metrics/mrr"
require_relative "eval_ruby/metrics/ndcg"
require_relative "eval_ruby/result"
require_relative "eval_ruby/evaluator"
require_relative "eval_ruby/report"
require_relative "eval_ruby/dataset"
require_relative "eval_ruby/comparison"

# Evaluation framework for LLM and RAG applications.
# Measures quality metrics like faithfulness, relevance, context precision,
# and answer correctness. Think Ragas or DeepEval for Ruby.
#
# @example Quick evaluation
#   result = EvalRuby.evaluate(
#     question: "What is Ruby?",
#     answer: "A programming language",
#     context: ["Ruby is a dynamic, open source programming language."],
#     ground_truth: "Ruby is a programming language created by Matz."
#   )
#   puts result.faithfulness  # => 0.95
#   puts result.overall       # => 0.87
#
# @example Retrieval evaluation
#   result = EvalRuby.evaluate_retrieval(
#     question: "What is Ruby?",
#     retrieved: ["doc_a", "doc_b", "doc_c"],
#     relevant: ["doc_a", "doc_c"]
#   )
#   puts result.precision_at_k(3) # => 0.67
module EvalRuby
  class Error < StandardError; end
  class APIError < Error; end
  class TimeoutError < Error; end
  class InvalidResponseError < Error; end

  class << self
    # @return [Configuration] the current configuration
    def configuration
      @configuration ||= Configuration.new
    end

    # Yields the configuration for modification.
    #
    # @yieldparam config [Configuration]
    # @return [void]
    def configure
      yield(configuration)
    end

    # Resets configuration to defaults.
    #
    # @return [Configuration]
    def reset_configuration!
      @configuration = Configuration.new
    end

    # Evaluates an LLM response across multiple quality metrics.
    #
    # @param question [String] the input question
    # @param answer [String] the LLM-generated answer
    # @param context [Array<String>] retrieved context chunks
    # @param ground_truth [String, nil] expected correct answer
    # @return [Result]
    def evaluate(question:, answer:, context: [], ground_truth: nil)
      Evaluator.new.evaluate(
        question: question,
        answer: answer,
        context: context,
        ground_truth: ground_truth
      )
    end

    # Evaluates retrieval quality using IR metrics.
    #
    # @param question [String] the input question
    # @param retrieved [Array<String>] retrieved document IDs
    # @param relevant [Array<String>] ground-truth relevant document IDs
    # @return [RetrievalResult]
    def evaluate_retrieval(question:, retrieved:, relevant:)
      Evaluator.new.evaluate_retrieval(
        question: question,
        retrieved: retrieved,
        relevant: relevant
      )
    end

    # Evaluates a batch of samples, optionally running them through a pipeline.
    #
    # @param dataset [Dataset, Array<Hash>] samples to evaluate
    # @param pipeline [#query, nil] optional RAG pipeline to run queries through
    # @return [Report]
    def evaluate_batch(dataset, pipeline: nil)
      samples = dataset.is_a?(Dataset) ? dataset.samples : dataset
      evaluator = Evaluator.new
      start_time = Time.now

      results = samples.map do |sample|
        if pipeline
          response = pipeline.query(sample[:question])
          evaluator.evaluate(
            question: sample[:question],
            answer: response.respond_to?(:text) ? response.text : response.to_s,
            context: response.respond_to?(:context) ? response.context : sample[:context],
            ground_truth: sample[:ground_truth]
          )
        else
          evaluator.evaluate(**sample.slice(:question, :answer, :context, :ground_truth))
        end
      end

      Report.new(results: results, samples: samples, duration: Time.now - start_time)
    end

    # Compares two evaluation reports with statistical significance testing.
    #
    # @param report_a [Report] baseline report
    # @param report_b [Report] comparison report
    # @return [Comparison]
    def compare(report_a, report_b)
      Comparison.new(report_a, report_b)
    end
  end
end
