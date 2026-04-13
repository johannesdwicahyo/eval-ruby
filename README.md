# eval-ruby

Evaluation framework for LLM and RAG applications in Ruby. Measures quality metrics like faithfulness, relevance, context precision, and answer correctness.

Think [Ragas](https://github.com/explodinggradients/ragas) or [DeepEval](https://github.com/confident-ai/deepeval) for Ruby.

## Installation

```ruby
gem "eval-ruby"
```

## Quick Start

```ruby
require "eval_ruby"

EvalRuby.configure do |config|
  config.judge_llm = :openai  # or :anthropic
  config.judge_model = "gpt-4o"
  config.api_key = ENV["OPENAI_API_KEY"]
end

result = EvalRuby.evaluate(
  question: "What is the capital of France?",
  answer: "The capital of France is Paris.",
  context: ["Paris is the capital of France."],
  ground_truth: "Paris"
)

result.faithfulness      # => 0.95
result.relevance         # => 0.92
result.context_precision # => 0.85
result.correctness       # => 0.98
result.overall           # => 0.94
```

## Metrics

### LLM-as-Judge
- **Faithfulness** — Is the answer supported by the context?
- **Relevance** — Does the answer address the question?
- **Correctness** — Does the answer match the ground truth?
- **Context Precision** — Are retrieved contexts relevant?
- **Context Recall** — Do contexts cover the ground truth?

### Retrieval Metrics
- **Precision@K** / **Recall@K**
- **MRR** (Mean Reciprocal Rank)
- **NDCG** (Normalized Discounted Cumulative Gain)
- **Hit Rate**

### Embedding-Based

- **Semantic Similarity** — cosine similarity between answer and ground truth via a pluggable embedder. Judge-free, fast, deterministic; useful for chatbot regression testing where you want a reference-based score without an LLM call.

## Semantic Similarity

`SemanticSimilarity` is opt-in (not part of the default `Evaluator` roster in v0.3.0). Instantiate it directly when you need reference-based scoring without an LLM judge — for example, scoring a chatbot's actual response against a fixed expected response.

```ruby
EvalRuby.configure do |config|
  config.api_key        = ENV["OPENAI_API_KEY"]        # shared with judge by default
  config.embedder_model = "text-embedding-3-small"      # default; also supports text-embedding-3-large
  # config.embedder_api_key = ENV["OTHER_KEY"]          # optional; falls back to api_key
end

embedder = EvalRuby::Embedders::OpenAI.new(EvalRuby.configuration)
metric   = EvalRuby::Metrics::SemanticSimilarity.new(embedder: embedder)

result = metric.call(
  answer:       "Paris is the capital of France",
  ground_truth: "The capital of France is Paris"
)

result[:score]              # => 0.92
result[:details][:cosine]   # => 0.92 (raw, pre-clamp)
result[:details][:model]    # => "text-embedding-3-small"
```

**When to use `SemanticSimilarity` vs `Correctness`:**

| | `Correctness` | `SemanticSimilarity` |
|---|---|---|
| Backend | LLM judge (GPT-4, Claude, …) | Embeddings + cosine |
| Cost per call | $$ (judge LLM tokens) | $ (embedding tokens) |
| Latency | High (LLM generation) | Low (embedding lookup) |
| Determinism | Low (model-dependent) | High |
| Reasoning | Natural-language rationale in details | Raw cosine value |
| Best for | Nuanced/subjective answers | Regression tests, bulk scoring |

## Retrieval Evaluation

```ruby
result = EvalRuby.evaluate_retrieval(
  question: "What is Ruby?",
  retrieved: ["Ruby is...", "Python is...", "Java is..."],
  relevant: ["Ruby is..."]
)

result.precision_at_k(1)  # => 1.0
result.mrr                # => 1.0
result.ndcg               # => 0.63
```

## Batch Evaluation

```ruby
report = EvalRuby.evaluate_batch(dataset)
report.summary
report.worst(5)
report.failures(threshold: 0.8)
report.to_csv("results.csv")
```

## Test Integration

### Minitest

```ruby
require "eval_ruby/minitest"

class TestRAG < Minitest::Test
  include EvalRuby::Assertions

  def test_faithfulness
    assert_faithful answer, context, threshold: 0.8
  end

  def test_no_hallucination
    refute_hallucination answer, context
  end
end
```

### RSpec

```ruby
require "eval_ruby/rspec"

RSpec.describe "RAG" do
  include EvalRuby::RSpecMatchers

  it "produces faithful answers" do
    expect(answer).to be_faithful_to(context).with_threshold(0.8)
  end
end
```

## A/B Comparison

```ruby
comparison = EvalRuby.compare(report_a, report_b)
comparison.summary
comparison.significant_improvements  # => [:faithfulness, :context_precision]
```

## License

MIT
