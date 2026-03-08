# frozen_string_literal: true

require "test_helper"

class TestCorrectness < Minitest::Test
  def test_llm_correctness
    judge = StubJudge.new({"reasoning" => "The answer matches the ground truth", "score" => 0.98})
    metric = EvalRuby::Metrics::Correctness.new(judge: judge)
    result = metric.call(answer: "Paris", ground_truth: "Paris")

    assert_equal 0.98, result[:score]
  end

  def test_string_similarity_exact_match
    metric = EvalRuby::Metrics::Correctness.new
    result = metric.call(answer: "Paris", ground_truth: "Paris")

    assert_equal 1.0, result[:score]
    assert_equal :exact_match, result[:details][:method]
  end

  def test_string_similarity_partial_match
    metric = EvalRuby::Metrics::Correctness.new
    result = metric.call(
      answer: "The capital of France is Paris",
      ground_truth: "Paris is the capital"
    )

    assert result[:score] > 0.0
    assert result[:score] <= 1.0
    assert_equal :token_overlap, result[:details][:method]
  end

  def test_string_similarity_no_match
    metric = EvalRuby::Metrics::Correctness.new
    result = metric.call(answer: "Berlin", ground_truth: "Paris")

    assert_equal 0.0, result[:score]
  end

  def test_empty_answer
    metric = EvalRuby::Metrics::Correctness.new
    result = metric.call(answer: "", ground_truth: "Paris")

    assert_equal 0.0, result[:score]
  end
end
