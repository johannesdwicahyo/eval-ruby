# frozen_string_literal: true

require "test_helper"
require "tmpdir"

class TestReport < Minitest::Test
  def setup
    @results = [
      EvalRuby::Result.new(scores: {faithfulness: 0.9, relevance: 0.85}),
      EvalRuby::Result.new(scores: {faithfulness: 0.7, relevance: 0.95}),
      EvalRuby::Result.new(scores: {faithfulness: 0.8, relevance: 0.90})
    ]
    @report = EvalRuby::Report.new(results: @results, duration: 12.5)
  end

  def test_summary
    summary = @report.summary
    assert_includes summary, "faithfulness"
    assert_includes summary, "relevance"
    assert_includes summary, "3 samples"
    assert_includes summary, "12.5s"
  end

  def test_metric_stats
    stats = @report.metric_stats
    assert_in_delta 0.8, stats[:faithfulness][:mean], 0.001
    assert_in_delta 0.9, stats[:relevance][:mean], 0.001
  end

  def test_worst
    worst = @report.worst(1)
    assert_equal 1, worst.length
    # The result with lowest overall should be first
    assert worst.first.overall <= @results.map(&:overall).max
  end

  def test_failures
    failures = @report.failures(threshold: 0.88)
    assert failures.any? { |r| r.overall < 0.88 }
  end

  def test_to_csv
    Dir.mktmpdir do |dir|
      path = File.join(dir, "results.csv")
      @report.to_csv(path)
      content = File.read(path)
      assert_includes content, "faithfulness"
      assert_includes content, "relevance"
      assert_includes content, "overall"
    end
  end

  def test_to_json
    Dir.mktmpdir do |dir|
      path = File.join(dir, "results.json")
      @report.to_json(path)
      data = JSON.parse(File.read(path))
      assert_equal 3, data["results"].length
      assert data.key?("summary")
    end
  end

  def test_empty_report
    report = EvalRuby::Report.new(results: [])
    assert_equal({}, report.metric_stats)
    assert_equal [], report.worst
    assert_equal [], report.failures
  end
end
