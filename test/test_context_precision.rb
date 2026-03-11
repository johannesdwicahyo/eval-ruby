# frozen_string_literal: true

require "test_helper"

class TestContextPrecision < Minitest::Test
  def test_all_contexts_relevant
    judge = StubJudge.new({
      "evaluations" => [
        {"index" => 0, "relevant" => true},
        {"index" => 1, "relevant" => true}
      ],
      "score" => 1.0
    })

    metric = EvalRuby::Metrics::ContextPrecision.new(judge: judge)
    result = metric.call(
      question: "What is the capital of France?",
      context: ["Paris is the capital of France.", "France is in Europe."]
    )

    assert_equal 1.0, result[:score]
    assert_equal 2, result[:details][:evaluations].length
  end

  def test_no_contexts_relevant
    judge = StubJudge.new({
      "evaluations" => [
        {"index" => 0, "relevant" => false},
        {"index" => 1, "relevant" => false}
      ],
      "score" => 0.0
    })

    metric = EvalRuby::Metrics::ContextPrecision.new(judge: judge)
    result = metric.call(
      question: "What is the capital of France?",
      context: ["Ruby is a programming language.", "Dogs are pets."]
    )

    assert_equal 0.0, result[:score]
  end

  def test_partial_relevance
    judge = StubJudge.new({
      "evaluations" => [
        {"index" => 0, "relevant" => true},
        {"index" => 1, "relevant" => false},
        {"index" => 2, "relevant" => true}
      ],
      "score" => 0.67
    })

    metric = EvalRuby::Metrics::ContextPrecision.new(judge: judge)
    result = metric.call(
      question: "What is Ruby?",
      context: [
        "Ruby is a programming language.",
        "The weather is nice today.",
        "Ruby was created by Matz in 1995."
      ]
    )

    assert_in_delta 0.67, result[:score], 0.01
  end

  def test_empty_context_returns_zero
    judge = StubJudge.new({"evaluations" => [], "score" => 0.0})
    metric = EvalRuby::Metrics::ContextPrecision.new(judge: judge)
    result = metric.call(question: "test", context: [])

    assert_equal 0.0, result[:score]
    # judge should not be called for empty context
    assert_equal 0, judge.call_count
  end

  def test_string_context_converted_to_array
    judge = StubJudge.new({
      "evaluations" => [{"index" => 0, "relevant" => true}],
      "score" => 1.0
    })

    metric = EvalRuby::Metrics::ContextPrecision.new(judge: judge)
    result = metric.call(question: "What is Ruby?", context: "Ruby is a language.")

    assert_equal 1.0, result[:score]
    assert_equal 1, judge.call_count
  end

  def test_score_clamped_to_range
    judge = StubJudge.new({"evaluations" => [], "score" => 1.5})
    metric = EvalRuby::Metrics::ContextPrecision.new(judge: judge)
    result = metric.call(question: "test", context: ["test"])

    assert_equal 1.0, result[:score]
  end

  def test_score_clamped_negative
    judge = StubJudge.new({"evaluations" => [], "score" => -0.5})
    metric = EvalRuby::Metrics::ContextPrecision.new(judge: judge)
    result = metric.call(question: "test", context: ["test"])

    assert_equal 0.0, result[:score]
  end

  def test_invalid_response_raises
    judge = StubJudge.new({"invalid" => "response"})
    metric = EvalRuby::Metrics::ContextPrecision.new(judge: judge)

    assert_raises(EvalRuby::Error) do
      metric.call(question: "test", context: ["test"])
    end
  end

  def test_nil_response_raises
    judge = StubJudge.new(nil)
    metric = EvalRuby::Metrics::ContextPrecision.new(judge: judge)

    assert_raises(EvalRuby::Error) do
      metric.call(question: "test", context: ["test"])
    end
  end

  def test_missing_evaluations_key_returns_empty_array
    judge = StubJudge.new({"score" => 0.8})
    metric = EvalRuby::Metrics::ContextPrecision.new(judge: judge)
    result = metric.call(question: "test", context: ["test"])

    assert_equal 0.8, result[:score]
    assert_equal [], result[:details][:evaluations]
  end
end
