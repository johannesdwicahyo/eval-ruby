# frozen_string_literal: true

module EvalRuby
  module Metrics
    class Faithfulness < Base
      PROMPT_TEMPLATE = <<~PROMPT
        Given the following context and answer, evaluate whether the answer
        is faithful to (supported by) the context.

        For each claim in the answer, determine if it is:
        1. SUPPORTED - directly supported by the context
        2. NOT SUPPORTED - contradicts or is not mentioned in the context

        Context:
        %{context}

        Answer:
        %{answer}

        List each claim and whether it is SUPPORTED or NOT SUPPORTED.
        Then give a faithfulness score from 0.0 to 1.0 where:
        - 1.0 = all claims are supported
        - 0.0 = no claims are supported

        Respond in JSON: {"claims": [{"claim": "...", "supported": true}], "score": 0.0}
      PROMPT

      def call(answer:, context:, **_kwargs)
        context_text = Array(context).join("\n\n")
        prompt = format(PROMPT_TEMPLATE, context: context_text, answer: answer)

        result = judge.call(prompt)
        raise Error, "Judge returned invalid response for faithfulness" unless result&.key?("score")

        {
          score: result["score"].to_f.clamp(0.0, 1.0),
          details: {claims: result["claims"] || []}
        }
      end
    end
  end
end
