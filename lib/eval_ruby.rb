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

module EvalRuby
  class Error < StandardError; end
  class APIError < Error; end
  class TimeoutError < Error; end
  class InvalidResponseError < Error; end

  class << self
    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield(configuration)
    end

    def reset_configuration!
      @configuration = Configuration.new
    end

    def evaluate(question:, answer:, context: [], ground_truth: nil)
      Evaluator.new.evaluate(
        question: question,
        answer: answer,
        context: context,
        ground_truth: ground_truth
      )
    end

    def evaluate_retrieval(question:, retrieved:, relevant:)
      Evaluator.new.evaluate_retrieval(
        question: question,
        retrieved: retrieved,
        relevant: relevant
      )
    end

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

    def compare(report_a, report_b)
      Comparison.new(report_a, report_b)
    end
  end
end
