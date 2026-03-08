# frozen_string_literal: true

require "eval_ruby"

# Configure the judge LLM
EvalRuby.configure do |config|
  config.judge_llm = :openai
  config.judge_model = "gpt-4o"
  config.api_key = ENV["OPENAI_API_KEY"]
end

# Evaluate a single RAG response
result = EvalRuby.evaluate(
  question: "What is the capital of France?",
  answer: "The capital of France is Paris, which is also its largest city.",
  context: [
    "Paris is the capital and most populous city of France.",
    "France is a country in Western Europe."
  ],
  ground_truth: "Paris"
)

puts result
puts
puts "Faithfulness:      #{result.faithfulness}"
puts "Relevance:         #{result.relevance}"
puts "Context Precision: #{result.context_precision}"
puts "Context Recall:    #{result.context_recall}"
puts "Correctness:       #{result.correctness}"
puts "Overall:           #{result.overall}"
