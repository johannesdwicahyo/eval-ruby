# frozen_string_literal: true

module EvalRuby
  module Metrics
    class Relevance < Base
      PROMPT_TEMPLATE = <<~PROMPT
        Given the following question and answer, evaluate whether the answer
        is relevant to and addresses the question.

        Question:
        %{question}

        Answer:
        %{answer}

        Evaluate relevance on a scale from 0.0 to 1.0 where:
        - 1.0 = the answer fully and directly addresses the question
        - 0.5 = the answer partially addresses the question
        - 0.0 = the answer is completely irrelevant to the question

        Respond in JSON: {"reasoning": "...", "score": 0.0}
      PROMPT

      def call(question:, answer:, **_kwargs)
        prompt = format(PROMPT_TEMPLATE, question: question, answer: answer)

        result = judge.call(prompt)
        raise Error, "Judge returned invalid response for relevance" unless result&.key?("score")

        {
          score: result["score"].to_f.clamp(0.0, 1.0),
          details: {reasoning: result["reasoning"]}
        }
      end
    end
  end
end
