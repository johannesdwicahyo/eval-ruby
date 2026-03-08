# frozen_string_literal: true

require "test_helper"

class TestAssertions < Minitest::Test
  def test_result_overall
    result = EvalRuby::Result.new(scores: {faithfulness: 0.9, relevance: 0.8})
    assert_in_delta 0.85, result.overall, 0.001
  end

  def test_result_to_h
    result = EvalRuby::Result.new(scores: {faithfulness: 0.9, relevance: 0.8})
    hash = result.to_h
    assert_equal 0.9, hash[:faithfulness]
    assert_equal 0.8, hash[:relevance]
    assert hash.key?(:overall)
  end

  def test_result_to_s
    result = EvalRuby::Result.new(scores: {faithfulness: 0.9})
    assert_includes result.to_s, "faithfulness"
    assert_includes result.to_s, "0.9"
  end

  def test_result_with_custom_weights
    result = EvalRuby::Result.new(scores: {faithfulness: 1.0, relevance: 0.0})
    weighted = result.overall(weights: {faithfulness: 2.0, relevance: 1.0})
    assert_in_delta 2.0 / 3.0, weighted, 0.001
  end

  def test_result_missing_metric
    result = EvalRuby::Result.new(scores: {faithfulness: 0.9})
    assert_nil result.relevance
  end

  def test_configuration
    EvalRuby.configure do |config|
      config.judge_llm = :anthropic
      config.judge_model = "claude-sonnet-4-6"
    end

    assert_equal :anthropic, EvalRuby.configuration.judge_llm
    assert_equal "claude-sonnet-4-6", EvalRuby.configuration.judge_model
  ensure
    EvalRuby.reset_configuration!
  end

  def test_comparison
    results_a = [
      EvalRuby::Result.new(scores: {faithfulness: 0.7}),
      EvalRuby::Result.new(scores: {faithfulness: 0.75}),
      EvalRuby::Result.new(scores: {faithfulness: 0.72})
    ]
    results_b = [
      EvalRuby::Result.new(scores: {faithfulness: 0.9}),
      EvalRuby::Result.new(scores: {faithfulness: 0.92}),
      EvalRuby::Result.new(scores: {faithfulness: 0.88})
    ]

    report_a = EvalRuby::Report.new(results: results_a)
    report_b = EvalRuby::Report.new(results: results_b)
    comparison = EvalRuby::Comparison.new(report_a, report_b)

    summary = comparison.summary
    assert_includes summary, "faithfulness"
    assert_includes summary, "Delta"

    improvements = comparison.significant_improvements
    assert_includes improvements, :faithfulness
  end

  def test_comparison_no_significance
    results_a = [
      EvalRuby::Result.new(scores: {faithfulness: 0.85}),
      EvalRuby::Result.new(scores: {faithfulness: 0.86}),
      EvalRuby::Result.new(scores: {faithfulness: 0.84})
    ]
    results_b = [
      EvalRuby::Result.new(scores: {faithfulness: 0.855}),
      EvalRuby::Result.new(scores: {faithfulness: 0.856}),
      EvalRuby::Result.new(scores: {faithfulness: 0.854})
    ]

    report_a = EvalRuby::Report.new(results: results_a)
    report_b = EvalRuby::Report.new(results: results_b)
    comparison = EvalRuby::Comparison.new(report_a, report_b)

    # Very small differences shouldn't be significant
    improvements = comparison.significant_improvements
    refute_includes improvements, :faithfulness
  end
end
