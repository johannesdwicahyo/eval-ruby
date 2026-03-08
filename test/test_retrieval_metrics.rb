# frozen_string_literal: true

require "test_helper"

class TestRetrievalMetrics < Minitest::Test
  def setup
    @retrieved = ["doc_a", "doc_b", "doc_c", "doc_d", "doc_e"]
    @relevant = ["doc_a", "doc_c"]
  end

  # Precision@K
  def test_precision_at_1
    score = EvalRuby::Metrics::PrecisionAtK.new.call(retrieved: @retrieved, relevant: @relevant, k: 1)
    assert_equal 1.0, score  # doc_a is relevant
  end

  def test_precision_at_3
    score = EvalRuby::Metrics::PrecisionAtK.new.call(retrieved: @retrieved, relevant: @relevant, k: 3)
    assert_in_delta 2.0 / 3.0, score, 0.001  # doc_a, doc_c relevant out of 3
  end

  def test_precision_at_5
    score = EvalRuby::Metrics::PrecisionAtK.new.call(retrieved: @retrieved, relevant: @relevant, k: 5)
    assert_in_delta 0.4, score, 0.001
  end

  def test_precision_empty_retrieved
    score = EvalRuby::Metrics::PrecisionAtK.new.call(retrieved: [], relevant: @relevant, k: 3)
    assert_equal 0.0, score
  end

  # Recall@K
  def test_recall_at_1
    score = EvalRuby::Metrics::RecallAtK.new.call(retrieved: @retrieved, relevant: @relevant, k: 1)
    assert_equal 0.5, score  # doc_a found, doc_c not yet
  end

  def test_recall_at_3
    score = EvalRuby::Metrics::RecallAtK.new.call(retrieved: @retrieved, relevant: @relevant, k: 3)
    assert_equal 1.0, score  # both doc_a and doc_c found in top 3
  end

  def test_recall_empty_relevant
    score = EvalRuby::Metrics::RecallAtK.new.call(retrieved: @retrieved, relevant: [], k: 3)
    assert_equal 0.0, score
  end

  # MRR
  def test_mrr_first_position
    score = EvalRuby::Metrics::MRR.new.call(retrieved: @retrieved, relevant: @relevant)
    assert_equal 1.0, score  # doc_a is at position 1
  end

  def test_mrr_second_position
    retrieved = ["doc_b", "doc_a", "doc_c"]
    score = EvalRuby::Metrics::MRR.new.call(retrieved: retrieved, relevant: @relevant)
    assert_equal 0.5, score  # first relevant at position 2
  end

  def test_mrr_no_relevant
    score = EvalRuby::Metrics::MRR.new.call(retrieved: @retrieved, relevant: ["doc_z"])
    assert_equal 0.0, score
  end

  # NDCG
  def test_ndcg_perfect_ranking
    retrieved = ["doc_a", "doc_c", "doc_b"]
    score = EvalRuby::Metrics::NDCG.new.call(retrieved: retrieved, relevant: @relevant)
    assert_in_delta 1.0, score, 0.001
  end

  def test_ndcg_imperfect_ranking
    score = EvalRuby::Metrics::NDCG.new.call(retrieved: @retrieved, relevant: @relevant)
    assert score > 0.0
    assert score < 1.0
  end

  def test_ndcg_no_relevant
    score = EvalRuby::Metrics::NDCG.new.call(retrieved: @retrieved, relevant: [])
    assert_equal 0.0, score
  end

  def test_ndcg_with_k
    score = EvalRuby::Metrics::NDCG.new.call(retrieved: @retrieved, relevant: @relevant, k: 1)
    assert_equal 1.0, score  # doc_a is relevant at position 1
  end

  # RetrievalResult integration
  def test_retrieval_result
    result = EvalRuby::RetrievalResult.new(retrieved: @retrieved, relevant: @relevant)

    assert_equal 1.0, result.precision_at_k(1)
    assert_equal 0.5, result.recall_at_k(1)
    assert_equal 1.0, result.mrr
    assert_equal 1.0, result.hit_rate
    assert result.ndcg > 0.0
  end

  def test_retrieval_result_to_h
    result = EvalRuby::RetrievalResult.new(retrieved: @retrieved, relevant: @relevant)
    hash = result.to_h

    assert hash.key?(:precision_at_k)
    assert hash.key?(:recall_at_k)
    assert hash.key?(:mrr)
    assert hash.key?(:ndcg)
    assert hash.key?(:hit_rate)
  end
end
