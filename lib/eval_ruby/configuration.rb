# frozen_string_literal: true

module EvalRuby
  class Configuration
    attr_accessor :judge_llm, :judge_model, :api_key, :default_threshold,
                  :timeout, :max_retries

    def initialize
      @judge_llm = :openai
      @judge_model = "gpt-4o"
      @api_key = nil
      @default_threshold = 0.7
      @timeout = 30
      @max_retries = 3
    end
  end
end
