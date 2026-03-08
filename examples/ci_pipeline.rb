# frozen_string_literal: true

require "eval_ruby"

EvalRuby.configure do |config|
  config.judge_llm = :openai
  config.judge_model = "gpt-4o"
  config.api_key = ENV["OPENAI_API_KEY"]
  config.default_threshold = 0.8
end

# Load evaluation dataset
dataset = EvalRuby::Dataset.from_json("eval_dataset.json")

# Run evaluation
report = EvalRuby.evaluate_batch(dataset)

# Export results
report.to_csv("eval_results.csv")
report.to_json("eval_results.json")

# Print summary
puts report.summary

# Check for failures
failures = report.failures(threshold: 0.8)
if failures.any?
  puts "\n#{failures.size} samples below threshold:"
  report.worst(5).each_with_index do |result, i|
    puts "  #{i + 1}. Overall: #{result.overall&.round(4)} - #{result.scores}"
  end
  exit 1
else
  puts "\nAll samples passed!"
  exit 0
end
