# frozen_string_literal: true

module EvalRuby
  # Global configuration for EvalRuby.
  #
  # @example
  #   EvalRuby.configure do |config|
  #     config.judge_llm = :openai
  #     config.api_key = ENV["OPENAI_API_KEY"]
  #     config.judge_model = "gpt-4o"
  #   end
  class Configuration
    # @return [Symbol] LLM provider for judge (:openai or :anthropic)
    attr_accessor :judge_llm

    # @return [String] model name for the judge LLM
    attr_accessor :judge_model

    # @return [String, nil] API key for the judge LLM provider
    attr_accessor :api_key

    # @return [Float] default threshold for pass/fail decisions
    attr_accessor :default_threshold

    # @return [Integer] HTTP request timeout in seconds
    attr_accessor :timeout

    # @return [Integer] maximum number of retries on transient failures
    attr_accessor :max_retries

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
