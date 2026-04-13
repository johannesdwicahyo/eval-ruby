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

# Stub embedder for testing embedding-based metrics without real API calls.
# Accepts either a fixed Array<Array<Float>>, a Hash keyed by text, or a Proc.
class StubEmbedder < EvalRuby::Embedders::Base
  def initialize(vectors, model: "stub-embedder")
    @vectors = vectors
    @model = model
    @call_count = 0
    @last_inputs = nil
  end

  attr_reader :call_count, :last_inputs

  def call(texts)
    @call_count += 1
    @last_inputs = texts

    case @vectors
    when Proc  then @vectors.call(texts)
    when Hash  then texts.map { |t| @vectors.fetch(t) { raise "StubEmbedder: no vector configured for #{t.inspect}" } }
    else            @vectors
    end
  end

  def model
    @model
  end
end

def openai_embeddings_response(vectors)
  {
    "object" => "list",
    "data" => vectors.each_with_index.map { |vec, i| {"object" => "embedding", "index" => i, "embedding" => vec} },
    "model" => "text-embedding-3-small",
    "usage" => {"prompt_tokens" => 10, "total_tokens" => 10}
  }
end
