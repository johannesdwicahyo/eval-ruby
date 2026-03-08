# frozen_string_literal: true

require "test_helper"
require "tmpdir"

class TestDataset < Minitest::Test
  def test_add_samples
    dataset = EvalRuby::Dataset.new("test")
    dataset.add(question: "What is Ruby?", ground_truth: "A programming language")
    dataset.add(question: "What is Rails?", ground_truth: "A web framework")

    assert_equal 2, dataset.size
    assert_equal "What is Ruby?", dataset[0][:question]
  end

  def test_enumerable
    dataset = EvalRuby::Dataset.new("test")
    dataset.add(question: "Q1", ground_truth: "A1")
    dataset.add(question: "Q2", ground_truth: "A2")

    questions = dataset.map { |s| s[:question] }
    assert_equal %w[Q1 Q2], questions
  end

  def test_csv_round_trip
    Dir.mktmpdir do |dir|
      path = File.join(dir, "test.csv")

      dataset = EvalRuby::Dataset.new("test")
      dataset.add(question: "What is Ruby?", answer: "A language", context: ["Ruby is..."], ground_truth: "A language")
      dataset.to_csv(path)

      loaded = EvalRuby::Dataset.from_csv(path)
      assert_equal 1, loaded.size
      assert_equal "What is Ruby?", loaded[0][:question]
      assert_equal "A language", loaded[0][:answer]
      assert_equal ["Ruby is..."], loaded[0][:context]
    end
  end

  def test_json_round_trip
    Dir.mktmpdir do |dir|
      path = File.join(dir, "test.json")

      dataset = EvalRuby::Dataset.new("test")
      dataset.add(question: "What is Ruby?", answer: "A language", context: ["Ruby is..."], ground_truth: "A language")
      dataset.to_json(path)

      loaded = EvalRuby::Dataset.from_json(path)
      assert_equal 1, loaded.size
      assert_equal "What is Ruby?", loaded[0][:question]
    end
  end

  def test_from_json_array_format
    Dir.mktmpdir do |dir|
      path = File.join(dir, "test.json")
      File.write(path, JSON.generate([
        {"question" => "Q1", "answer" => "A1", "context" => ["C1"], "ground_truth" => "A1"}
      ]))

      loaded = EvalRuby::Dataset.from_json(path)
      assert_equal 1, loaded.size
      assert_equal "Q1", loaded[0][:question]
    end
  end

  def test_add_with_relevant_contexts
    dataset = EvalRuby::Dataset.new("test")
    dataset.add(question: "Q1", relevant_contexts: ["ctx1", "ctx2"])

    assert_equal ["ctx1", "ctx2"], dataset[0][:context]
  end
end
