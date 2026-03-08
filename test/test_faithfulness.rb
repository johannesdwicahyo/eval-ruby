# frozen_string_literal: true

require "test_helper"

class TestFaithfulness < Minitest::Test
  def test_high_faithfulness
    judge = StubJudge.new({
      "claims" => [
        {"claim" => "Paris is the capital of France", "supported" => true},
        {"claim" => "Paris is the largest city", "supported" => true}
      ],
      "score" => 1.0
    })

    metric = EvalRuby::Metrics::Faithfulness.new(judge: judge)
    result = metric.call(
      answer: "Paris is the capital of France and its largest city.",
      context: ["Paris is the capital and most populous city of France."]
    )

    assert_equal 1.0, result[:score]
    assert_equal 2, result[:details][:claims].length
  end

  def test_low_faithfulness
    judge = StubJudge.new({
      "claims" => [
        {"claim" => "Berlin is the capital of France", "supported" => false}
      ],
      "score" => 0.0
    })

    metric = EvalRuby::Metrics::Faithfulness.new(judge: judge)
    result = metric.call(
      answer: "Berlin is the capital of France.",
      context: ["Paris is the capital of France."]
    )

    assert_equal 0.0, result[:score]
  end

  def test_partial_faithfulness
    judge = StubJudge.new({
      "claims" => [
        {"claim" => "Ruby was created in 1995", "supported" => true},
        {"claim" => "Ruby was created by Guido van Rossum", "supported" => false}
      ],
      "score" => 0.5
    })

    metric = EvalRuby::Metrics::Faithfulness.new(judge: judge)
    result = metric.call(
      answer: "Ruby was created in 1995 by Guido van Rossum.",
      context: ["Ruby is a programming language created by Yukihiro Matsumoto in 1995."]
    )

    assert_equal 0.5, result[:score]
  end

  def test_score_clamped
    judge = StubJudge.new({"claims" => [], "score" => 1.5})
    metric = EvalRuby::Metrics::Faithfulness.new(judge: judge)
    result = metric.call(answer: "test", context: ["test"])

    assert_equal 1.0, result[:score]
  end

  def test_invalid_response_raises
    judge = StubJudge.new({"invalid" => "response"})
    metric = EvalRuby::Metrics::Faithfulness.new(judge: judge)

    assert_raises(EvalRuby::Error) do
      metric.call(answer: "test", context: ["test"])
    end
  end
end
