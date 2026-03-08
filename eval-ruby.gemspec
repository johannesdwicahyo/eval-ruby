# frozen_string_literal: true

require_relative "lib/eval_ruby/version"

Gem::Specification.new do |spec|
  spec.name = "eval-ruby"
  spec.version = EvalRuby::VERSION
  spec.authors = ["Johannes Dwi Cahyo"]
  spec.homepage = "https://github.com/johannesdwicahyo/eval-ruby"
  spec.summary = "Evaluation framework for LLM and RAG applications in Ruby"
  spec.description = "Measures quality metrics like faithfulness, relevance, context precision, " \
                     "and answer correctness for LLM and RAG applications. " \
                     "Think Ragas or DeepEval for Ruby."
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.1.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"

  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |f|
      (File.expand_path(f) == __FILE__) ||
        f.start_with?("test/", "spec/", "examples/", ".git")
    end
  end
  spec.require_paths = ["lib"]

  spec.add_development_dependency "minitest", "~> 5.0"
  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "webmock", "~> 3.0"
end
