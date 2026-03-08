# frozen_string_literal: true

require "test_helper"

class TestRelevance < Minitest::Test
  def test_high_relevance
    judge = StubJudge.new({"reasoning" => "The answer directly addresses the question", "score" => 0.95})
    metric = EvalRuby::Metrics::Relevance.new(judge: judge)
    result = metric.call(question: "What is Ruby?", answer: "Ruby is a programming language.")

    assert_equal 0.95, result[:score]
  end

  def test_low_relevance
    judge = StubJudge.new({"reasoning" => "The answer is about Python, not Ruby", "score" => 0.1})
    metric = EvalRuby::Metrics::Relevance.new(judge: judge)
    result = metric.call(question: "What is Ruby?", answer: "Python is a great language.")

    assert_equal 0.1, result[:score]
  end

  def test_invalid_response_raises
    judge = StubJudge.new(nil)
    metric = EvalRuby::Metrics::Relevance.new(judge: judge)

    assert_raises(EvalRuby::Error) do
      metric.call(question: "test", answer: "test")
    end
  end
end
