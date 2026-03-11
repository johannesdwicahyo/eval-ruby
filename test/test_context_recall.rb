# frozen_string_literal: true

require "test_helper"

class TestContextRecall < Minitest::Test
  def test_full_recall
    judge = StubJudge.new({
      "statements" => [
        {"statement" => "Paris is the capital", "attributed" => true},
        {"statement" => "Paris is in France", "attributed" => true}
      ],
      "score" => 1.0
    })

    metric = EvalRuby::Metrics::ContextRecall.new(judge: judge)
    result = metric.call(
      context: ["Paris is the capital of France, located in Western Europe."],
      ground_truth: "Paris is the capital of France."
    )

    assert_equal 1.0, result[:score]
    assert_equal 2, result[:details][:statements].length
  end

  def test_no_recall
    judge = StubJudge.new({
      "statements" => [
        {"statement" => "Tokyo is the capital of Japan", "attributed" => false}
      ],
      "score" => 0.0
    })

    metric = EvalRuby::Metrics::ContextRecall.new(judge: judge)
    result = metric.call(
      context: ["Ruby is a programming language."],
      ground_truth: "Tokyo is the capital of Japan."
    )

    assert_equal 0.0, result[:score]
  end

  def test_partial_recall
    judge = StubJudge.new({
      "statements" => [
        {"statement" => "Ruby was created in 1995", "attributed" => true},
        {"statement" => "Ruby 3.0 added Ractors", "attributed" => false}
      ],
      "score" => 0.5
    })

    metric = EvalRuby::Metrics::ContextRecall.new(judge: judge)
    result = metric.call(
      context: ["Ruby was created by Yukihiro Matsumoto in 1995."],
      ground_truth: "Ruby was created in 1995. Ruby 3.0 added Ractors."
    )

    assert_equal 0.5, result[:score]
  end

  def test_empty_context_returns_zero
    judge = StubJudge.new({"statements" => [], "score" => 0.0})
    metric = EvalRuby::Metrics::ContextRecall.new(judge: judge)
    result = metric.call(context: [], ground_truth: "Some truth")

    assert_equal 0.0, result[:score]
    assert_equal 0, judge.call_count
  end

  def test_string_context_converted_to_array
    judge = StubJudge.new({
      "statements" => [{"statement" => "test", "attributed" => true}],
      "score" => 1.0
    })

    metric = EvalRuby::Metrics::ContextRecall.new(judge: judge)
    result = metric.call(context: "Single context string", ground_truth: "test")

    assert_equal 1.0, result[:score]
    assert_equal 1, judge.call_count
  end

  def test_score_clamped_above
    judge = StubJudge.new({"statements" => [], "score" => 2.0})
    metric = EvalRuby::Metrics::ContextRecall.new(judge: judge)
    result = metric.call(context: ["ctx"], ground_truth: "truth")

    assert_equal 1.0, result[:score]
  end

  def test_score_clamped_below
    judge = StubJudge.new({"statements" => [], "score" => -1.0})
    metric = EvalRuby::Metrics::ContextRecall.new(judge: judge)
    result = metric.call(context: ["ctx"], ground_truth: "truth")

    assert_equal 0.0, result[:score]
  end

  def test_invalid_response_raises
    judge = StubJudge.new({"wrong_key" => "data"})
    metric = EvalRuby::Metrics::ContextRecall.new(judge: judge)

    assert_raises(EvalRuby::Error) do
      metric.call(context: ["ctx"], ground_truth: "truth")
    end
  end

  def test_nil_response_raises
    judge = StubJudge.new(nil)
    metric = EvalRuby::Metrics::ContextRecall.new(judge: judge)

    assert_raises(EvalRuby::Error) do
      metric.call(context: ["ctx"], ground_truth: "truth")
    end
  end

  def test_missing_statements_key_returns_empty_array
    judge = StubJudge.new({"score" => 0.75})
    metric = EvalRuby::Metrics::ContextRecall.new(judge: judge)
    result = metric.call(context: ["ctx"], ground_truth: "truth")

    assert_equal 0.75, result[:score]
    assert_equal [], result[:details][:statements]
  end

  def test_multiple_contexts
    judge = StubJudge.new({
      "statements" => [
        {"statement" => "Ruby is dynamic", "attributed" => true},
        {"statement" => "Ruby is object-oriented", "attributed" => true}
      ],
      "score" => 1.0
    })

    metric = EvalRuby::Metrics::ContextRecall.new(judge: judge)
    result = metric.call(
      context: [
        "Ruby is a dynamic language.",
        "Ruby is fully object-oriented."
      ],
      ground_truth: "Ruby is a dynamic, object-oriented language."
    )

    assert_equal 1.0, result[:score]
  end
end
