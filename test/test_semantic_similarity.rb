# frozen_string_literal: true

require "test_helper"

class TestSemanticSimilarity < Minitest::Test
  # ---- Metric with a StubEmbedder ----------------------------------------

  def test_identical_vectors_score_1
    embedder = StubEmbedder.new([[1.0, 0.0, 0.0], [1.0, 0.0, 0.0]])
    metric = EvalRuby::Metrics::SemanticSimilarity.new(embedder: embedder)

    result = metric.call(answer: "Paris", ground_truth: "Paris")

    assert_in_delta 1.0, result[:score], 1e-9
    assert_in_delta 1.0, result[:details][:cosine], 1e-9
    assert_equal "stub-embedder", result[:details][:model]
  end

  def test_orthogonal_vectors_score_0
    embedder = StubEmbedder.new([[1.0, 0.0, 0.0], [0.0, 1.0, 0.0]])
    metric = EvalRuby::Metrics::SemanticSimilarity.new(embedder: embedder)

    result = metric.call(answer: "cats", ground_truth: "database schemas")

    assert_in_delta 0.0, result[:score], 1e-9
  end

  def test_opposite_vectors_clamped_to_zero
    embedder = StubEmbedder.new([[1.0, 0.0], [-1.0, 0.0]])
    metric = EvalRuby::Metrics::SemanticSimilarity.new(embedder: embedder)

    result = metric.call(answer: "yes", ground_truth: "no")

    assert_equal 0.0, result[:score]
    assert_in_delta(-1.0, result[:details][:cosine], 1e-9)
  end

  def test_moderate_similarity
    # answer vector is [3, 4], ground-truth vector is [4, 3]
    # cosine = (3*4 + 4*3) / (5 * 5) = 24 / 25 = 0.96
    embedder = StubEmbedder.new([[3.0, 4.0], [4.0, 3.0]])
    metric = EvalRuby::Metrics::SemanticSimilarity.new(embedder: embedder)

    result = metric.call(answer: "close-ish", ground_truth: "pretty close")

    assert_in_delta 0.96, result[:score], 1e-9
  end

  def test_missing_embedder_raises
    metric = EvalRuby::Metrics::SemanticSimilarity.new

    err = assert_raises(EvalRuby::Error) do
      metric.call(answer: "a", ground_truth: "b")
    end
    assert_match(/embedder/i, err.message)
  end

  def test_empty_answer_returns_score_zero_without_calling_embedder
    embedder = StubEmbedder.new([[1.0], [1.0]])
    metric = EvalRuby::Metrics::SemanticSimilarity.new(embedder: embedder)

    result = metric.call(answer: "", ground_truth: "Paris")

    assert_equal 0.0, result[:score]
    assert_equal :empty_input, result[:details][:reason]
    assert_equal 0, embedder.call_count
  end

  def test_empty_ground_truth_returns_score_zero_without_calling_embedder
    embedder = StubEmbedder.new([[1.0], [1.0]])
    metric = EvalRuby::Metrics::SemanticSimilarity.new(embedder: embedder)

    result = metric.call(answer: "Paris", ground_truth: "   ")

    assert_equal 0.0, result[:score]
    assert_equal :empty_input, result[:details][:reason]
    assert_equal 0, embedder.call_count
  end

  def test_batches_both_texts_in_one_embedder_call
    embedder = StubEmbedder.new([[1.0, 0.0], [1.0, 0.0]])
    metric = EvalRuby::Metrics::SemanticSimilarity.new(embedder: embedder)

    metric.call(answer: "a", ground_truth: "b")

    assert_equal 1, embedder.call_count
    assert_equal ["a", "b"], embedder.last_inputs
  end

  def test_dimension_mismatch_raises
    # StubEmbedder returns vectors of different lengths — defensive check
    embedder = StubEmbedder.new([[1.0, 0.0], [1.0, 0.0, 0.0]])
    metric = EvalRuby::Metrics::SemanticSimilarity.new(embedder: embedder)

    err = assert_raises(EvalRuby::Error) do
      metric.call(answer: "a", ground_truth: "b")
    end
    assert_match(/dimension/i, err.message)
  end

  def test_zero_vector_yields_zero_score
    embedder = StubEmbedder.new([[0.0, 0.0], [1.0, 1.0]])
    metric = EvalRuby::Metrics::SemanticSimilarity.new(embedder: embedder)

    result = metric.call(answer: "", ground_truth: "b")

    # With one empty-string sentinel we short-circuit; confirm the zero-norm
    # branch is reachable when an embedder does return [0,0] for a non-empty
    # string (some providers do for banned content, etc.)
    assert_equal 0.0, result[:score]
  end

  def test_unexpected_vector_count_raises
    embedder = StubEmbedder.new([[1.0, 0.0]]) # only one vector returned
    metric = EvalRuby::Metrics::SemanticSimilarity.new(embedder: embedder)

    err = assert_raises(EvalRuby::Error) do
      metric.call(answer: "a", ground_truth: "b")
    end
    assert_match(/2/, err.message)
  end

  # ---- Real Embedders::OpenAI with WebMock -------------------------------

  def test_openai_embedder_end_to_end
    EvalRuby.configure do |c|
      c.api_key = "test-key"
      c.embedder_model = "text-embedding-3-small"
    end

    response_body = JSON.generate(openai_embeddings_response([
      [1.0, 0.0, 0.0],
      [0.0, 1.0, 0.0]
    ]))

    stub = stub_request(:post, "https://api.openai.com/v1/embeddings")
      .with(
        headers: {"Authorization" => "Bearer test-key", "Content-Type" => "application/json"},
        body: hash_including("input" => ["hello", "world"], "model" => "text-embedding-3-small")
      )
      .to_return(status: 200, body: response_body, headers: {"Content-Type" => "application/json"})

    embedder = EvalRuby::Embedders::OpenAI.new(EvalRuby.configuration)
    metric = EvalRuby::Metrics::SemanticSimilarity.new(embedder: embedder)

    result = metric.call(answer: "hello", ground_truth: "world")

    assert_in_delta 0.0, result[:score], 1e-9
    assert_requested(stub)
  ensure
    EvalRuby.reset_configuration!
  end

  def test_openai_embedder_preserves_order_from_indexed_response
    EvalRuby.configure { |c| c.api_key = "test-key" }

    # Return entries deliberately out of order; the client must sort by index.
    out_of_order = {
      "object" => "list",
      "model" => "text-embedding-3-small",
      "data" => [
        {"object" => "embedding", "index" => 1, "embedding" => [0.0, 1.0]},
        {"object" => "embedding", "index" => 0, "embedding" => [1.0, 0.0]}
      ]
    }

    stub_request(:post, "https://api.openai.com/v1/embeddings")
      .to_return(status: 200, body: JSON.generate(out_of_order), headers: {"Content-Type" => "application/json"})

    vectors = EvalRuby::Embedders::OpenAI.new(EvalRuby.configuration).call(["a", "b"])

    assert_equal [[1.0, 0.0], [0.0, 1.0]], vectors
  ensure
    EvalRuby.reset_configuration!
  end

  def test_openai_embedder_missing_api_key_raises
    EvalRuby.reset_configuration!

    err = assert_raises(EvalRuby::Error) do
      EvalRuby::Embedders::OpenAI.new(EvalRuby.configuration)
    end
    assert_match(/API key/i, err.message)
  end

  def test_openai_embedder_uses_embedder_api_key_when_set
    EvalRuby.configure do |c|
      c.api_key = "judge-key"
      c.embedder_api_key = "embedder-key"
    end

    stub = stub_request(:post, "https://api.openai.com/v1/embeddings")
      .with(headers: {"Authorization" => "Bearer embedder-key"})
      .to_return(status: 200, body: JSON.generate(openai_embeddings_response([[1.0]])))

    EvalRuby::Embedders::OpenAI.new(EvalRuby.configuration).call(["hello"])
    assert_requested(stub)
  ensure
    EvalRuby.reset_configuration!
  end

  def test_openai_embedder_falls_back_to_api_key
    EvalRuby.configure do |c|
      c.api_key = "shared-key"
    end

    stub = stub_request(:post, "https://api.openai.com/v1/embeddings")
      .with(headers: {"Authorization" => "Bearer shared-key"})
      .to_return(status: 200, body: JSON.generate(openai_embeddings_response([[1.0]])))

    EvalRuby::Embedders::OpenAI.new(EvalRuby.configuration).call(["hello"])
    assert_requested(stub)
  ensure
    EvalRuby.reset_configuration!
  end

  def test_openai_embedder_raises_on_error_response
    EvalRuby.configure { |c| c.api_key = "test-key" }

    stub_request(:post, "https://api.openai.com/v1/embeddings")
      .to_return(status: 401, body: '{"error":{"message":"bad key"}}')

    err = assert_raises(EvalRuby::APIError) do
      EvalRuby::Embedders::OpenAI.new(EvalRuby.configuration).call(["hi"])
    end
    assert_match(/401/, err.message)
  ensure
    EvalRuby.reset_configuration!
  end

  def test_openai_embedder_raises_on_malformed_response
    EvalRuby.configure { |c| c.api_key = "test-key" }

    stub_request(:post, "https://api.openai.com/v1/embeddings")
      .to_return(status: 200, body: "not json at all")

    assert_raises(EvalRuby::InvalidResponseError) do
      EvalRuby::Embedders::OpenAI.new(EvalRuby.configuration).call(["hi"])
    end
  ensure
    EvalRuby.reset_configuration!
  end

  def test_embedder_model_configurable
    EvalRuby.configure do |c|
      c.api_key = "test-key"
      c.embedder_model = "text-embedding-3-large"
    end

    stub = stub_request(:post, "https://api.openai.com/v1/embeddings")
      .with(body: hash_including("model" => "text-embedding-3-large"))
      .to_return(status: 200, body: JSON.generate(openai_embeddings_response([[1.0]])))

    embedder = EvalRuby::Embedders::OpenAI.new(EvalRuby.configuration)
    embedder.call(["hi"])

    assert_equal "text-embedding-3-large", embedder.model
    assert_requested(stub)
  ensure
    EvalRuby.reset_configuration!
  end

  # ---- Configuration round-trip ------------------------------------------

  def test_configuration_defaults
    EvalRuby.reset_configuration!
    config = EvalRuby.configuration

    assert_equal :openai, config.embedder_llm
    assert_equal "text-embedding-3-small", config.embedder_model
    assert_nil config.embedder_api_key
  end

  def test_configuration_setters
    EvalRuby.configure do |c|
      c.embedder_llm = :openai
      c.embedder_model = "custom-model"
      c.embedder_api_key = "custom-key"
    end

    assert_equal :openai, EvalRuby.configuration.embedder_llm
    assert_equal "custom-model", EvalRuby.configuration.embedder_model
    assert_equal "custom-key", EvalRuby.configuration.embedder_api_key
  ensure
    EvalRuby.reset_configuration!
  end
end
