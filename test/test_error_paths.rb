# frozen_string_literal: true

require "test_helper"

class TestErrorPaths < Minitest::Test
  # --- Error hierarchy ---

  def test_error_inherits_from_standard_error
    assert EvalRuby::Error < StandardError
  end

  def test_api_error_inherits_from_error
    assert EvalRuby::APIError < EvalRuby::Error
  end

  def test_timeout_error_inherits_from_error
    assert EvalRuby::TimeoutError < EvalRuby::Error
  end

  def test_invalid_response_error_inherits_from_error
    assert EvalRuby::InvalidResponseError < EvalRuby::Error
  end

  # --- Evaluator error paths ---

  def test_evaluator_unknown_judge_raises
    config = EvalRuby::Configuration.new
    config.judge_llm = :unknown_provider

    assert_raises(EvalRuby::Error) do
      EvalRuby::Evaluator.new(config)
    end
  end

  def test_openai_judge_requires_api_key
    config = EvalRuby::Configuration.new
    config.judge_llm = :openai
    config.api_key = nil

    assert_raises(EvalRuby::Error) do
      EvalRuby::Judges::OpenAI.new(config)
    end
  end

  def test_openai_judge_requires_non_empty_api_key
    config = EvalRuby::Configuration.new
    config.api_key = ""

    assert_raises(EvalRuby::Error) do
      EvalRuby::Judges::OpenAI.new(config)
    end
  end

  def test_anthropic_judge_requires_api_key
    config = EvalRuby::Configuration.new
    config.judge_llm = :anthropic
    config.api_key = nil

    assert_raises(EvalRuby::Error) do
      EvalRuby::Judges::Anthropic.new(config)
    end
  end

  # --- Metrics base class ---

  def test_base_metric_call_raises_not_implemented
    metric = EvalRuby::Metrics::Base.new

    assert_raises(NotImplementedError) do
      metric.call
    end
  end

  def test_base_metric_accepts_judge
    judge = StubJudge.new({})
    metric = EvalRuby::Metrics::Base.new(judge: judge)

    assert_equal judge, metric.judge
  end

  def test_base_metric_judge_defaults_to_nil
    metric = EvalRuby::Metrics::Base.new
    assert_nil metric.judge
  end

  # --- Judges base class ---

  def test_judges_base_call_raises_not_implemented
    config = EvalRuby::Configuration.new
    judge = EvalRuby::Judges::Base.new(config)

    assert_raises(NotImplementedError) do
      judge.call("prompt")
    end
  end

  # --- Faithfulness edge cases ---

  def test_faithfulness_context_as_string
    judge = StubJudge.new({"claims" => [], "score" => 0.8})
    metric = EvalRuby::Metrics::Faithfulness.new(judge: judge)
    result = metric.call(answer: "test", context: "single string context")

    assert_equal 0.8, result[:score]
  end

  def test_faithfulness_nil_judge_response
    judge = StubJudge.new(nil)
    metric = EvalRuby::Metrics::Faithfulness.new(judge: judge)

    assert_raises(EvalRuby::Error) do
      metric.call(answer: "test", context: ["ctx"])
    end
  end

  # --- Relevance edge cases ---

  def test_relevance_score_clamped
    judge = StubJudge.new({"reasoning" => "test", "score" => 5.0})
    metric = EvalRuby::Metrics::Relevance.new(judge: judge)
    result = metric.call(question: "q", answer: "a")

    assert_equal 1.0, result[:score]
  end

  # --- Correctness edge cases ---

  def test_correctness_empty_ground_truth
    metric = EvalRuby::Metrics::Correctness.new
    result = metric.call(answer: "", ground_truth: "")

    assert_equal 1.0, result[:score]
    assert_equal :exact_match, result[:details][:method]
  end

  def test_correctness_case_insensitive_token_overlap
    metric = EvalRuby::Metrics::Correctness.new
    result = metric.call(answer: "PARIS", ground_truth: "paris")

    assert_equal 1.0, result[:score]
  end

  # --- Result edge cases ---

  def test_result_overall_with_empty_scores
    result = EvalRuby::Result.new(scores: {})
    assert_nil result.overall
  end

  def test_result_overall_with_nil_values
    result = EvalRuby::Result.new(scores: {faithfulness: nil, relevance: 0.8})
    assert_in_delta 0.8, result.overall, 0.001
  end

  def test_result_to_s_with_nil_score
    result = EvalRuby::Result.new(scores: {faithfulness: nil})
    assert_includes result.to_s, "N/A"
  end

  # --- Configuration ---

  def test_configuration_defaults
    config = EvalRuby::Configuration.new
    assert_equal :openai, config.judge_llm
    assert_equal "gpt-4o", config.judge_model
    assert_nil config.api_key
    assert_equal 0.7, config.default_threshold
    assert_equal 30, config.timeout
    assert_equal 3, config.max_retries
  end

  def test_reset_configuration
    EvalRuby.configure { |c| c.judge_model = "custom-model" }
    assert_equal "custom-model", EvalRuby.configuration.judge_model

    EvalRuby.reset_configuration!
    assert_equal "gpt-4o", EvalRuby.configuration.judge_model
  end

  # --- RetrievalResult edge cases ---

  def test_retrieval_result_empty_lists
    result = EvalRuby::RetrievalResult.new(retrieved: [], relevant: [])
    assert_equal 0.0, result.precision_at_k(5)
    assert_equal 0.0, result.recall_at_k(5)
    assert_equal 0.0, result.mrr
    assert_equal 0.0, result.ndcg
    assert_equal 0.0, result.hit_rate
  end

  def test_retrieval_result_no_hits
    result = EvalRuby::RetrievalResult.new(
      retrieved: ["a", "b", "c"],
      relevant: ["x", "y"]
    )
    assert_equal 0.0, result.hit_rate
    assert_equal 0.0, result.mrr
  end

  # --- Report edge cases ---

  def test_report_long_duration_formatting
    report = EvalRuby::Report.new(
      results: [EvalRuby::Result.new(scores: {faithfulness: 0.9})],
      duration: 125.7
    )
    summary = report.summary
    assert_includes summary, "2m"
  end

  def test_report_nil_duration
    report = EvalRuby::Report.new(
      results: [EvalRuby::Result.new(scores: {faithfulness: 0.9})]
    )
    summary = report.summary
    assert_includes summary, "N/A"
  end

  def test_report_single_result_std
    report = EvalRuby::Report.new(
      results: [EvalRuby::Result.new(scores: {faithfulness: 0.9})]
    )
    stats = report.metric_stats
    assert_equal 0.0, stats[:faithfulness][:std]
  end
end
