# eval-ruby — Milestones

> **Source of truth:** https://github.com/johannesdwicahyo/eval-ruby/milestones
> **Last synced:** 2026-04-14

This file mirrors the GitHub milestones for this repo. Edit the milestone or issues on GitHub and re-sync, do not hand-edit.

## v1.0.0 — Production Ready (**open**)

_Phase 5: custom metrics, dashboard, multi-provider judges, performance optimization_

- [ ] #20 Add custom metric definitions
- [ ] #21 Add ruby_llm judge provider
- [ ] #22 Add reference-based metrics: BLEU and ROUGE
- [ ] #23 Add metric selection to evaluate()
- [ ] #24 Add configurable metric weights for overall score
- [ ] #25 Add CHANGELOG.md and release automation

## v0.5.0 — Testing Framework Integration (**open**)

_CI/test-framework integration: JUnit XML output, regression detection, GitHub Actions workflow, expanded RSpec matchers, expanded Minitest assertions._

- [ ] #15 Add JUnit XML output for CI integration
- [ ] #16 Add regression detection against baseline
- [ ] #17 Add GitHub Actions workflow for eval-ruby CI
- [ ] #18 Add more RSpec matchers for all metrics
- [ ] #19 Add more Minitest assertions for all metrics

## v0.4.0 — Batch, Reporting & Cost (**open**)

_Batch evaluation ergonomics and reporting: cost tracking, async/parallel execution, HTML report generation._

- [ ] #10 Add cost tracking per evaluation
- [ ] #11 Add async/parallel evaluation for batch processing
- [ ] #12 Add HTML report generation

## v0.3.0 — Embedders & SemanticSimilarity (**closed** — released 2026-04-13)

_Embedders::Base + Embedders::OpenAI abstraction; Metrics::SemanticSimilarity (cosine via embedder); Configuration#embedder_*; evaluate_batch progress callback; hardened Dataset.generate. Reshaped from the original "Batch, Reporting & Datasets" plan to unblock omnibot Wicara eval integration. Cost tracking, async/parallel, HTML reports moved to v0.4.0; CI/test-framework integration formerly v0.4.0 moved to v0.5.0._

- [x] #13 Add progress callback for batch evaluation
- [x] #14 Harden Dataset.generate with validation and tests
- [x] #26 Add Embedders::Base abstraction
- [x] #27 Add Embedders::OpenAI implementation
- [x] #28 Add Metrics::SemanticSimilarity
- [x] #29 Wire Configuration#embedder_* and module entrypoint
- [x] #30 Document embedding-based metrics in README

## v0.2.0 — Test Coverage & Quality (**closed**)

_Comprehensive test coverage, better error messages, documentation_

- [x] #5 Add tests for ContextPrecision metric
- [x] #6 Add tests for ContextRecall metric
- [x] #7 Add tests for RSpec matchers
- [x] #8 Add tests for error paths and edge cases
- [x] #9 Add YARD documentation to public API

## v0.1.1 — Bug Fixes & Stability (**closed**)

_Critical fixes and robustness improvements_

- [x] #1 Fix: nil dereference in parse_json_response
- [x] #2 Fix: implement retry logic using max_retries config
- [x] #3 Fix: handle missing file in Dataset.generate
- [x] #4 Improve error messages with actual response data
