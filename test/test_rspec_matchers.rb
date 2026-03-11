# frozen_string_literal: true

require "test_helper"
require "eval_ruby/rspec"

class TestRSpecMatchers < Minitest::Test
  # --- BeFaithfulTo ---

  def test_be_faithful_matches_when_above_threshold
    judge = StubJudge.new({"claims" => [{"claim" => "test", "supported" => true}], "score" => 0.95})
    matcher = EvalRuby::RSpecMatchers::BeFaithfulTo.new(["Context text"], judge: judge)

    assert matcher.matches?("Faithful answer")
  end

  def test_be_faithful_fails_when_below_threshold
    judge = StubJudge.new({"claims" => [{"claim" => "test", "supported" => false}], "score" => 0.3})
    matcher = EvalRuby::RSpecMatchers::BeFaithfulTo.new(["Context text"], judge: judge)

    refute matcher.matches?("Unfaithful answer")
  end

  def test_be_faithful_custom_threshold
    judge = StubJudge.new({"claims" => [], "score" => 0.6})
    matcher = EvalRuby::RSpecMatchers::BeFaithfulTo.new(["Context"], judge: judge)
    matcher.with_threshold(0.5)

    assert matcher.matches?("answer")
  end

  def test_be_faithful_custom_threshold_fail
    judge = StubJudge.new({"claims" => [], "score" => 0.6})
    matcher = EvalRuby::RSpecMatchers::BeFaithfulTo.new(["Context"], judge: judge)
    matcher.with_threshold(0.9)

    refute matcher.matches?("answer")
  end

  def test_be_faithful_failure_message
    judge = StubJudge.new({"claims" => [], "score" => 0.45})
    matcher = EvalRuby::RSpecMatchers::BeFaithfulTo.new(["Context"], judge: judge)
    matcher.matches?("answer")

    msg = matcher.failure_message
    assert_includes msg, "0.8"       # default threshold
    assert_includes msg, "0.45"      # actual score
    assert_includes msg, "faithful"
  end

  def test_be_faithful_failure_message_when_negated
    judge = StubJudge.new({"claims" => [], "score" => 0.95})
    matcher = EvalRuby::RSpecMatchers::BeFaithfulTo.new(["Context"], judge: judge)
    matcher.matches?("answer")

    msg = matcher.failure_message_when_negated
    assert_includes msg, "not to be faithful"
    assert_includes msg, "0.95"
  end

  def test_be_faithful_context_as_string
    judge = StubJudge.new({"claims" => [], "score" => 0.9})
    matcher = EvalRuby::RSpecMatchers::BeFaithfulTo.new("Single context string", judge: judge)

    assert matcher.matches?("answer")
  end

  def test_be_faithful_with_threshold_returns_self
    judge = StubJudge.new({"claims" => [], "score" => 0.9})
    matcher = EvalRuby::RSpecMatchers::BeFaithfulTo.new(["Context"], judge: judge)
    returned = matcher.with_threshold(0.5)

    assert_same matcher, returned
  end

  # --- HavePrecisionAtK ---

  def test_have_precision_at_k_matches
    result = EvalRuby::RetrievalResult.new(
      retrieved: ["doc_a", "doc_b", "doc_c"],
      relevant: ["doc_a", "doc_c"]
    )

    matcher = EvalRuby::RSpecMatchers::HavePrecisionAtK.new(3)
    assert matcher.matches?(result)
  end

  def test_have_precision_at_k_fails_below_threshold
    result = EvalRuby::RetrievalResult.new(
      retrieved: ["doc_a", "doc_b", "doc_c", "doc_d", "doc_e"],
      relevant: ["doc_a"]
    )

    matcher = EvalRuby::RSpecMatchers::HavePrecisionAtK.new(5)
    refute matcher.matches?(result)  # 1/5 = 0.2, below default 0.5
  end

  def test_have_precision_at_k_custom_threshold
    result = EvalRuby::RetrievalResult.new(
      retrieved: ["doc_a", "doc_b", "doc_c"],
      relevant: ["doc_a"]
    )

    matcher = EvalRuby::RSpecMatchers::HavePrecisionAtK.new(3)
    matcher.above(0.3)
    assert matcher.matches?(result)  # 1/3 = 0.33, above 0.3
  end

  def test_have_precision_at_k_failure_message
    result = EvalRuby::RetrievalResult.new(
      retrieved: ["doc_a", "doc_b"],
      relevant: ["doc_c"]
    )

    matcher = EvalRuby::RSpecMatchers::HavePrecisionAtK.new(2)
    matcher.matches?(result)

    msg = matcher.failure_message
    assert_includes msg, "precision@2"
    assert_includes msg, "0.5"   # default threshold
    assert_includes msg, "0.0"   # actual score
  end

  def test_have_precision_at_k_raises_for_non_retrieval_result
    matcher = EvalRuby::RSpecMatchers::HavePrecisionAtK.new(3)

    assert_raises(ArgumentError) do
      matcher.matches?("not a retrieval result")
    end
  end

  def test_have_precision_at_k_above_returns_self
    matcher = EvalRuby::RSpecMatchers::HavePrecisionAtK.new(3)
    returned = matcher.above(0.8)

    assert_same matcher, returned
  end

  # --- DSL methods ---

  def test_dsl_be_faithful_to
    klass = Class.new { include EvalRuby::RSpecMatchers }
    obj = klass.new
    matcher = obj.be_faithful_to(["context"])

    assert_instance_of EvalRuby::RSpecMatchers::BeFaithfulTo, matcher
  end

  def test_dsl_have_precision_at_k
    klass = Class.new { include EvalRuby::RSpecMatchers }
    obj = klass.new
    matcher = obj.have_precision_at_k(5)

    assert_instance_of EvalRuby::RSpecMatchers::HavePrecisionAtK, matcher
  end
end
