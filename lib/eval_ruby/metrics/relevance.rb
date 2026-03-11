# frozen_string_literal: true

module EvalRuby
  module Metrics
    # Measures whether an answer is relevant to the question.
    # Uses an LLM judge to evaluate relevance on a 0.0-1.0 scale.
    #
    # @example
    #   metric = Relevance.new(judge: judge)
    #   result = metric.call(question: "What is Ruby?", answer: "Ruby is a language.")
    #   result[:score] # => 0.95
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

      # @param question [String] the input question
      # @param answer [String] the LLM-generated answer
      # @return [Hash] :score (Float 0.0-1.0) and :details (:reasoning String)
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
