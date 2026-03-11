# frozen_string_literal: true

module EvalRuby
  module Metrics
    # Measures whether retrieved contexts contain enough information to support the ground truth.
    # Uses an LLM judge to check if each ground truth statement is attributable to context.
    #
    # @example
    #   metric = ContextRecall.new(judge: judge)
    #   result = metric.call(context: ["Ruby was created in 1995."], ground_truth: "Ruby was created in 1995.")
    #   result[:score] # => 1.0
    class ContextRecall < Base
      PROMPT_TEMPLATE = <<~PROMPT
        Given the following ground truth answer and retrieved contexts, evaluate
        whether the contexts contain enough information to support the ground truth.

        Ground Truth:
        %{ground_truth}

        Contexts:
        %{contexts}

        For each statement in the ground truth, determine if it can be attributed
        to the retrieved contexts.

        Respond in JSON: {"statements": [{"statement": "...", "attributed": true}], "score": 0.0}
        The score should be the proportion of statements attributed to context (0.0 to 1.0).
      PROMPT

      # @param context [Array<String>, String] retrieved context chunks
      # @param ground_truth [String] expected correct answer
      # @return [Hash] :score (Float 0.0-1.0) and :details (:statements Array)
      def call(context:, ground_truth:, **_kwargs)
        contexts = context.is_a?(Array) ? context : [context.to_s]
        return {score: 0.0, details: {}} if contexts.empty?

        contexts_text = contexts.each_with_index.map { |c, i| "[#{i}] #{c}" }.join("\n\n")
        prompt = format(PROMPT_TEMPLATE, ground_truth: ground_truth, contexts: contexts_text)

        result = judge.call(prompt)
        raise Error, "Judge returned invalid response for context_recall" unless result&.key?("score")

        {
          score: result["score"].to_f.clamp(0.0, 1.0),
          details: {statements: result["statements"] || []}
        }
      end
    end
  end
end
