# frozen_string_literal: true

require "csv"
require "json"

module EvalRuby
  class Dataset
    include Enumerable

    attr_reader :name, :samples

    def initialize(name = "default")
      @name = name
      @samples = []
    end

    def add(question:, ground_truth: nil, relevant_contexts: [], answer: nil, context: [])
      @samples << {
        question: question,
        answer: answer,
        context: context.empty? ? relevant_contexts : context,
        ground_truth: ground_truth
      }
      self
    end

    def each(&block)
      @samples.each(&block)
    end

    def size
      @samples.size
    end

    def [](index)
      @samples[index]
    end

    def self.from_csv(path)
      dataset = new(File.basename(path, ".*"))
      CSV.foreach(path, headers: true) do |row|
        dataset.add(
          question: row["question"],
          answer: row["answer"],
          context: parse_array_field(row["context"]),
          ground_truth: row["ground_truth"]
        )
      end
      dataset
    end

    def self.from_json(path)
      dataset = new(File.basename(path, ".*"))
      data = JSON.parse(File.read(path))
      samples = data.is_a?(Array) ? data : data["samples"] || data["data"] || []
      samples.each do |sample|
        dataset.add(
          question: sample["question"],
          answer: sample["answer"],
          context: Array(sample["context"]),
          ground_truth: sample["ground_truth"]
        )
      end
      dataset
    end

    def to_csv(path)
      CSV.open(path, "w") do |csv|
        csv << %w[question answer context ground_truth]
        @samples.each do |sample|
          csv << [
            sample[:question],
            sample[:answer],
            JSON.generate(sample[:context]),
            sample[:ground_truth]
          ]
        end
      end
    end

    def to_json(path)
      File.write(path, JSON.pretty_generate({name: @name, samples: @samples}))
    end

    def self.generate(documents:, questions_per_doc: 5, llm: :openai)
      config = EvalRuby.configuration.dup
      config.judge_llm = llm
      judge = case llm
      when :openai then Judges::OpenAI.new(config)
      when :anthropic then Judges::Anthropic.new(config)
      else raise Error, "Unknown LLM: #{llm}"
      end

      dataset = new("generated")
      documents.each do |doc_path|
        content = File.read(doc_path)
        prompt = <<~PROMPT
          Given the following document, generate #{questions_per_doc} question-answer pairs
          that can be answered using the document content.

          Document:
          #{content}

          Respond in JSON: {"pairs": [{"question": "...", "answer": "...", "context": "relevant excerpt"}]}
        PROMPT

        result = judge.call(prompt)
        next unless result&.key?("pairs")

        result["pairs"].each do |pair|
          dataset.add(
            question: pair["question"],
            answer: pair["answer"],
            context: [pair["context"] || content],
            ground_truth: pair["answer"]
          )
        end
      end
      dataset
    end

    private_class_method def self.parse_array_field(value)
      return [] if value.nil? || value.empty?

      JSON.parse(value)
    rescue JSON::ParserError
      [value]
    end
  end
end
