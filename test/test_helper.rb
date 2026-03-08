# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "eval_ruby"
require "minitest/autorun"
require "webmock/minitest"
require "json"

# Stub judge for testing LLM-as-judge metrics without real API calls
class StubJudge < EvalRuby::Judges::Base
  def initialize(responses = {})
    @responses = responses
    @call_count = 0
  end

  attr_reader :call_count

  def call(prompt)
    @call_count += 1
    if @responses.is_a?(Proc)
      @responses.call(prompt)
    elsif @responses.is_a?(Array)
      @responses[@call_count - 1]
    else
      @responses
    end
  end
end

def openai_response(content)
  {
    "choices" => [
      {"message" => {"content" => JSON.generate(content)}}
    ]
  }
end
