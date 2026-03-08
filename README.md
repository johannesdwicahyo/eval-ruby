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
