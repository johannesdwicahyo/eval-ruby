# frozen_string_literal: true

module EvalRuby
  module Metrics
    # Measures factual correctness of an answer against ground truth.
    # Uses LLM judge when available, falls back to token overlap F1 score.
    #
    # @example With LLM judge
    #   metric = Correctness.new(judge: judge)
    #   result = metric.call(answer: "Paris", ground_truth: "Paris")
    #
    # @example Without judge (string similarity)
    #   metric = Correctness.new
    #   result = metric.call(answer: "The capital is Paris", ground_truth: "Paris is the capital")
    class Correctness < Base
      PROMPT_TEMPLATE = <<~PROMPT
        Given the following answer and ground truth, evaluate whether the answer
        is factually correct.

        Answer:
        %{answer}

        Ground Truth:
        %{ground_truth}

        Evaluate correctness on a scale from 0.0 to 1.0 where:
        - 1.0 = the answer is completely correct and matches the ground truth
        - 0.5 = the answer is partially correct
        - 0.0 = the answer is completely wrong

        Consider both semantic meaning and factual accuracy, not just exact string matching.

        Respond in JSON: {"reasoning": "...", "score": 0.0}
      PROMPT

      # @param answer [String] the LLM-generated answer
      # @param ground_truth [String] the expected correct answer
      # @return [Hash] :score (Float 0.0-1.0) and :details
      def call(answer:, ground_truth:, **_kwargs)
        if judge
          llm_score(answer, ground_truth)
        else
          string_similarity_score(answer, ground_truth)
        end
      end

      private

      def llm_score(answer, ground_truth)
        prompt = format(PROMPT_TEMPLATE, answer: answer, ground_truth: ground_truth)

        result = judge.call(prompt)
        raise Error, "Judge returned invalid response for correctness" unless result&.key?("score")

        {
          score: result["score"].to_f.clamp(0.0, 1.0),
          details: {reasoning: result["reasoning"]}
        }
      end

      def string_similarity_score(answer, ground_truth)
        answer_tokens = tokenize(answer)
        truth_tokens = tokenize(ground_truth)

        return {score: 1.0, details: {method: :exact_match}} if answer_tokens == truth_tokens
        return {score: 0.0, details: {method: :token_overlap}} if answer_tokens.empty? || truth_tokens.empty?

        overlap = (answer_tokens & truth_tokens).size
        precision = overlap.to_f / answer_tokens.size
        recall = overlap.to_f / truth_tokens.size
        f1 = precision + recall > 0 ? 2 * precision * recall / (precision + recall) : 0.0

        {score: f1.clamp(0.0, 1.0), details: {method: :token_overlap, precision: precision, recall: recall}}
      end

      def tokenize(text)
        text.downcase.scan(/\w+/)
      end
    end
  end
end
