# frozen_string_literal: true

require "eval_ruby"

EvalRuby.configure do |config|
  config.judge_llm = :openai
  config.judge_model = "gpt-4o"
  config.api_key = ENV["OPENAI_API_KEY"]
end

# Evaluate retrieval quality
retrieval_result = EvalRuby.evaluate_retrieval(
  question: "What is the capital of France?",
  retrieved: ["Paris is the capital...", "France is in Europe...", "Berlin is..."],
  relevant: ["Paris is the capital..."]
)

puts "Precision@1: #{retrieval_result.precision_at_k(1)}"
puts "Precision@3: #{retrieval_result.precision_at_k(3)}"
puts "Recall@3:    #{retrieval_result.recall_at_k(3)}"
puts "MRR:         #{retrieval_result.mrr}"
puts "NDCG:        #{retrieval_result.ndcg}"
puts "Hit Rate:    #{retrieval_result.hit_rate}"

# Batch evaluation
dataset = [
  {
    question: "What is Ruby?",
    answer: "Ruby is a dynamic programming language.",
    context: ["Ruby is a programming language created by Matz."],
    ground_truth: "Ruby is a dynamic programming language created by Yukihiro Matsumoto."
  },
  {
    question: "What is Rails?",
    answer: "Rails is a web framework for Ruby.",
    context: ["Ruby on Rails is a web application framework written in Ruby."],
    ground_truth: "Rails is a web application framework written in Ruby."
  }
]

report = EvalRuby.evaluate_batch(dataset)
puts "\n#{report.summary}"
