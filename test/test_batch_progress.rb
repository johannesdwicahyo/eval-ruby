# frozen_string_literal: true

require "test_helper"

class TestBatchProgress < Minitest::Test
  def setup
    EvalRuby.reset_configuration!
    EvalRuby.configure { |c| c.api_key = "test-key" }
    stub_generic_judge_response
  end

  def teardown
    EvalRuby.reset_configuration!
    WebMock.reset!
  end

  def test_evaluate_batch_without_block_preserves_behavior
    samples = [
      {question: "q1", answer: "a1", ground_truth: "a1"},
      {question: "q2", answer: "a2", ground_truth: "a2"}
    ]

    # No block — should still complete and return a Report without calling a nil proc.
    report = EvalRuby.evaluate_batch(samples)

    refute_nil report
    assert_equal 2, report.results.size
  end

  def test_evaluate_batch_yields_progress_per_sample
    samples = Array.new(3) { |i| {question: "q#{i}", answer: "a#{i}", ground_truth: "a#{i}"} }

    yielded = []
    EvalRuby.evaluate_batch(samples) { |p| yielded << p }

    assert_equal 3, yielded.size
    assert_equal [1, 2, 3], yielded.map(&:current)
    assert_equal [3, 3, 3], yielded.map(&:total)
  end

  def test_progress_percent_computed_correctly
    samples = Array.new(4) { |i| {question: "q#{i}", answer: "a#{i}", ground_truth: "a#{i}"} }

    yielded = []
    EvalRuby.evaluate_batch(samples) { |p| yielded << p }

    assert_equal [25.0, 50.0, 75.0, 100.0], yielded.map(&:percent)
  end

  def test_progress_elapsed_is_non_decreasing
    samples = Array.new(3) { |i| {question: "q#{i}", answer: "a#{i}", ground_truth: "a#{i}"} }

    yielded = []
    EvalRuby.evaluate_batch(samples) { |p| yielded << p }

    elapsed = yielded.map(&:elapsed)
    assert elapsed.each_cons(2).all? { |a, b| b >= a }, "elapsed should be non-decreasing, got #{elapsed}"
    assert elapsed.all? { |e| e >= 0 }
  end

  def test_empty_dataset_does_not_yield
    yielded = []
    EvalRuby.evaluate_batch([]) { |p| yielded << p }

    assert_empty yielded
  end

  def test_progress_struct_handles_zero_total
    p = EvalRuby::Progress.new(current: 0, total: 0, elapsed: 0.0)
    assert_equal 0.0, p.percent
  end

  def test_works_with_dataset_instance_not_just_array
    dataset = EvalRuby::Dataset.new("x")
    2.times { |i| dataset.add(question: "q#{i}", answer: "a#{i}", ground_truth: "a#{i}") }

    yielded = []
    EvalRuby.evaluate_batch(dataset) { |p| yielded << p }

    assert_equal [1, 2], yielded.map(&:current)
    assert_equal [2, 2], yielded.map(&:total)
  end

  private

  # Returns a generic passing judge response for every judged metric call.
  def stub_generic_judge_response
    body = JSON.generate(openai_response(
      "reasoning" => "ok",
      "score" => 0.9,
      "statements" => ["ok"],
      "verdict" => 1,
      "supported" => true,
      "relevant" => true
    ))
    stub_request(:post, "https://api.openai.com/v1/chat/completions")
      .to_return(status: 200, body: body, headers: {"Content-Type" => "application/json"})
  end
end
