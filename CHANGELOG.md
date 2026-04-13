# Changelog

All notable changes to this project are documented in this file.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.3.0] - 2026-04-13

Reshape release — the original v0.3.0 scope (cost tracking, async/parallel batch, HTML reports) was redistributed to a new **v0.4.0 "Batch, Reporting & Cost"** milestone, and the previous v0.4.0 "Testing Framework Integration" work slid to **v0.5.0**. This release instead prioritizes the API surface needed by the omnibot Wicara eval integration, plus the two quickly actionable items from the original v0.3.0 plan.

### Added
- `EvalRuby::Embedders::Base` — abstract base class for pluggable embedding backends, mirroring the existing `Judges::Base` pattern.
- `EvalRuby::Embedders::OpenAI` — OpenAI embeddings backend (`/v1/embeddings`) with retry/timeout handling and out-of-order response reassembly.
- `EvalRuby::Metrics::SemanticSimilarity` — Ragas-style answer-similarity metric. Computes cosine similarity between answer and ground-truth embeddings via an injected embedder. Judge-free, fast, deterministic; ideal for chatbot regression testing.
- `Configuration#embedder_llm`, `#embedder_model`, `#embedder_api_key` — new keys controlling the embedder. `embedder_api_key` falls back to `api_key` when unset, so most users only configure one OpenAI key.
- `EvalRuby.evaluate_batch(dataset) { |progress| ... }` — block form that yields an `EvalRuby::Progress` struct (`current`, `total`, `elapsed`, `percent`) after each sample. Backwards compatible — batch calls without a block behave exactly as before.

### Changed
- `Dataset.generate` hardened:
  - validates `questions_per_doc` is a positive integer
  - validates document paths exist (raises a clear error instead of a `File.read` crash)
  - expands directory paths via `Dir.glob(**/*)` to support "scan this folder" workflows
  - accepts a single path string, not just an array
  - tolerates malformed LLM responses (missing `pairs`, non-array `pairs`, non-hash entries, missing `question`/`answer`) — skips the bad pair rather than crashing the whole generation
  - tolerates a judge raising mid-batch — logs the failure as a skip and continues with the remaining documents
  - accepts an injected `judge:` parameter for testing (and for custom judge plumbing)

### Notes
- `SemanticSimilarity` is **opt-in** — not part of the default `Evaluator` roster. Instantiate it directly when you want reference-based scoring without an LLM judge.
- Deferred to v0.4.0: cost tracking per evaluation (#10), async/parallel batch evaluation (#11), HTML report generation (#12).
- Deferred to v0.5.0: CI/test-framework integration (JUnit XML, regression detection, GitHub Actions workflow, expanded matchers/assertions — formerly v0.4.0).

## [0.2.0] - 2026-03-17

### Added
- Comprehensive test suite covering all metrics, judges, datasets, reports, and error paths.
- YARD documentation across all public APIs.
- RSpec matchers and Minitest assertions for integration in user test suites.
- A/B comparison reports with statistical significance testing.

## [0.1.1] - 2026-03-10

### Fixed
- Transient API failures now retry with exponential backoff (previously a single timeout raised immediately).
- `Judges::OpenAI#initialize` rejects missing/empty API keys up front with a clear error message.
- String-context metrics now handle strings passed in place of arrays without crashing.
- Standard-deviation computation in `Report#summary` no longer divides by zero for single-sample reports.

### Added
- Error subclasses (`APIError`, `TimeoutError`, `InvalidResponseError`) so callers can rescue at the right granularity.

## [0.1.0] - 2026-03-09

- Initial release.
- LLM-as-judge metrics: faithfulness, relevance, correctness, context precision, context recall.
- Retrieval metrics: precision@k, recall@k, MRR, NDCG, hit rate.
- OpenAI and Anthropic judge backends.
- `Dataset` with CSV/JSON import and export.
- `Report` with per-metric summary, worst-cases, failure filtering, and CSV export.
- `Configuration` DSL for judge model, API key, threshold, timeout, retries.
