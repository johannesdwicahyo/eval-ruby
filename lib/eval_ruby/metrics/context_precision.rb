# frozen_string_literal: true

module EvalRuby
  module Metrics
    class ContextPrecision < Base
      PROMPT_TEMPLATE = <<~PROMPT
        Given the following question and a list of retrieved contexts, evaluate
        whether each context is relevant to answering the question.

        Question:
        %{question}

        Contexts:
        %{contexts}

        For each context, determine if it is RELEVANT or NOT RELEVANT to answering the question.

        Respond in JSON: {"evaluations": [{"index": 0, "relevant": true}], "score": 0.0}
        The score should be the proportion of relevant contexts (0.0 to 1.0).
      PROMPT

      def call(question:, context:, **_kwargs)
        contexts = Array(context)
        return {score: 0.0, details: {}} if contexts.empty?

        contexts_text = contexts.each_with_index.map { |c, i| "[#{i}] #{c}" }.join("\n\n")
        prompt = format(PROMPT_TEMPLATE, question: question, contexts: contexts_text)

        result = judge.call(prompt)
        raise Error, "Judge returned invalid response for context_precision" unless result&.key?("score")

        {
          score: result["score"].to_f.clamp(0.0, 1.0),
          details: {evaluations: result["evaluations"] || []}
        }
      end
    end
  end
end
