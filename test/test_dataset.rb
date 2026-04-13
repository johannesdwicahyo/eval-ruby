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

  # ---- Dataset.generate hardening -------------------------------------

  def test_generate_raises_on_non_positive_questions_per_doc
    Dir.mktmpdir do |dir|
      path = File.join(dir, "doc.txt")
      File.write(path, "content")

      err = assert_raises(EvalRuby::Error) do
        EvalRuby::Dataset.generate(documents: [path], questions_per_doc: 0, judge: StubJudge.new({}))
      end
      assert_match(/positive/, err.message)
    end
  end

  def test_generate_raises_on_non_integer_questions_per_doc
    Dir.mktmpdir do |dir|
      path = File.join(dir, "doc.txt")
      File.write(path, "content")

      assert_raises(EvalRuby::Error) do
        EvalRuby::Dataset.generate(documents: [path], questions_per_doc: 2.5, judge: StubJudge.new({}))
      end
    end
  end

  def test_generate_raises_on_missing_document_path
    err = assert_raises(EvalRuby::Error) do
      EvalRuby::Dataset.generate(documents: ["/no/such/path.txt"], judge: StubJudge.new({}))
    end
    assert_match(/does not exist/, err.message)
  end

  def test_generate_raises_when_no_documents_resolved
    Dir.mktmpdir do |dir|
      # Empty directory → no files → Error
      err = assert_raises(EvalRuby::Error) do
        EvalRuby::Dataset.generate(documents: [dir], judge: StubJudge.new({}))
      end
      assert_match(/No documents/, err.message)
    end
  end

  def test_generate_expands_directory_paths
    Dir.mktmpdir do |dir|
      File.write(File.join(dir, "a.txt"), "content a")
      File.write(File.join(dir, "b.txt"), "content b")

      judge = StubJudge.new({
        "pairs" => [{"question" => "Q", "answer" => "A", "context" => "ctx"}]
      })

      dataset = EvalRuby::Dataset.generate(documents: [dir], questions_per_doc: 1, judge: judge)

      assert_equal 2, judge.call_count # one call per file
      assert_equal 2, dataset.size
    end
  end

  def test_generate_accepts_single_path_string
    Dir.mktmpdir do |dir|
      path = File.join(dir, "doc.txt")
      File.write(path, "content")

      judge = StubJudge.new({"pairs" => [{"question" => "Q", "answer" => "A"}]})

      dataset = EvalRuby::Dataset.generate(documents: path, judge: judge)

      assert_equal 1, dataset.size
    end
  end

  def test_generate_skips_malformed_llm_response
    Dir.mktmpdir do |dir|
      path = File.join(dir, "doc.txt")
      File.write(path, "content")

      # Judge returns nil, then non-Hash, then Hash without "pairs", then Hash with non-Array pairs
      responses = [nil, "not a hash", {"oops" => "no pairs"}, {"pairs" => "not an array"}]
      judge = StubJudge.new(responses)

      # Each of these malformed responses should produce zero samples but not crash
      4.times do
        dataset = EvalRuby::Dataset.generate(documents: [path], questions_per_doc: 1, judge: judge)
        assert_equal 0, dataset.size
      end
    end
  end

  def test_generate_skips_pairs_missing_required_fields
    Dir.mktmpdir do |dir|
      path = File.join(dir, "doc.txt")
      File.write(path, "content")

      judge = StubJudge.new({
        "pairs" => [
          {"question" => "Good Q", "answer" => "Good A"},          # valid
          {"question" => "", "answer" => "A"},                     # empty Q
          {"question" => "Q", "answer" => ""},                     # empty A
          {"answer" => "A"},                                        # missing Q
          {"question" => "Q"},                                      # missing A
          {"question" => 42, "answer" => "A"},                     # non-string Q
          {"question" => "Q2", "answer" => "A2", "context" => "C2"} # valid
        ]
      })

      dataset = EvalRuby::Dataset.generate(documents: [path], judge: judge)

      assert_equal 2, dataset.size
      assert_equal "Good Q", dataset[0][:question]
      assert_equal "Q2", dataset[1][:question]
      assert_equal ["C2"], dataset[1][:context]
    end
  end

  def test_generate_falls_back_to_document_content_when_pair_has_no_context
    Dir.mktmpdir do |dir|
      path = File.join(dir, "doc.txt")
      File.write(path, "full document body")

      judge = StubJudge.new({
        "pairs" => [{"question" => "Q", "answer" => "A"}] # no "context" field
      })

      dataset = EvalRuby::Dataset.generate(documents: [path], judge: judge)

      assert_equal ["full document body"], dataset[0][:context]
    end
  end

  def test_generate_tolerates_judge_raising_mid_batch
    Dir.mktmpdir do |dir|
      path_a = File.join(dir, "a.txt")
      path_b = File.join(dir, "b.txt")
      File.write(path_a, "A")
      File.write(path_b, "B")

      # First call raises; second call returns a valid pair
      responses = lambda do |_prompt|
        @count ||= 0
        @count += 1
        raise "boom" if @count == 1
        {"pairs" => [{"question" => "Q", "answer" => "A"}]}
      end
      judge = StubJudge.new(responses)

      dataset = EvalRuby::Dataset.generate(documents: [dir], judge: judge)

      # First doc failed → skipped; second doc succeeded → 1 sample
      assert_equal 1, dataset.size
    end
  end

  def test_generate_uses_answer_as_ground_truth
    Dir.mktmpdir do |dir|
      path = File.join(dir, "doc.txt")
      File.write(path, "x")

      judge = StubJudge.new({"pairs" => [{"question" => "Q", "answer" => "The Answer"}]})

      dataset = EvalRuby::Dataset.generate(documents: [path], judge: judge)

      assert_equal "The Answer", dataset[0][:ground_truth]
    end
  end
end
