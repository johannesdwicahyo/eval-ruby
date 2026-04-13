# frozen_string_literal: true

require "csv"
require "json"

module EvalRuby
  # Collection of evaluation samples with import/export support.
  # Supports CSV, JSON, and programmatic construction.
  #
  # @example
  #   dataset = EvalRuby::Dataset.new("my_test_set")
  #   dataset.add(question: "What is Ruby?", answer: "A language", ground_truth: "A language")
  #   report = EvalRuby.evaluate_batch(dataset)
  class Dataset
    include Enumerable

    # @return [String] dataset name
    attr_reader :name

    # @return [Array<Hash>] sample entries
    attr_reader :samples

    # @param name [String] dataset name
    def initialize(name = "default")
      @name = name
      @samples = []
    end

    # Adds a sample to the dataset.
    #
    # @param question [String]
    # @param ground_truth [String, nil]
    # @param relevant_contexts [Array<String>] alias for context
    # @param answer [String, nil]
    # @param context [Array<String>]
    # @return [self]
    def add(question:, ground_truth: nil, relevant_contexts: [], answer: nil, context: [])
      @samples << {
        question: question,
        answer: answer,
        context: context.empty? ? relevant_contexts : context,
        ground_truth: ground_truth
      }
      self
    end

    # @yield [Hash] each sample
    def each(&block)
      @samples.each(&block)
    end

    # @return [Integer] number of samples
    def size
      @samples.size
    end

    # @param index [Integer]
    # @return [Hash] sample at index
    def [](index)
      @samples[index]
    end

    # Loads a dataset from a CSV file.
    #
    # @param path [String] path to CSV file
    # @return [Dataset]
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

    # Loads a dataset from a JSON file.
    #
    # @param path [String] path to JSON file
    # @return [Dataset]
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

    # Exports dataset to CSV.
    #
    # @param path [String] output file path
    # @return [void]
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

    # Exports dataset to JSON.
    #
    # @param path [String] output file path
    # @return [void]
    def to_json(path)
      File.write(path, JSON.pretty_generate({name: @name, samples: @samples}))
    end

    # Generates a dataset from documents using an LLM.
    #
    # Each document is read, passed to the LLM with a prompt asking for
    # +questions_per_doc+ QA pairs, and the resulting pairs are appended to
    # the dataset. Directory paths are expanded via +Dir.glob+. Missing paths
    # and malformed LLM responses raise or are skipped gracefully rather than
    # crashing the whole generation.
    #
    # @param documents [String, Array<String>] file paths or directory paths
    # @param questions_per_doc [Integer] number of QA pairs per document (must be > 0)
    # @param llm [Symbol] LLM provider (:openai or :anthropic)
    # @param judge [Judges::Base, nil] inject a pre-built judge (mainly for testing)
    # @return [Dataset]
    # @raise [EvalRuby::Error] on bad arguments or no documents found
    def self.generate(documents:, questions_per_doc: 5, llm: :openai, judge: nil)
      unless questions_per_doc.is_a?(Integer) && questions_per_doc.positive?
        raise Error, "questions_per_doc must be a positive integer, got #{questions_per_doc.inspect}"
      end

      document_paths = expand_document_paths(documents)
      raise Error, "No documents found in the provided paths" if document_paths.empty?

      judge ||= build_judge_for(llm)

      dataset = new("generated")
      document_paths.each do |doc_path|
        content = File.read(doc_path)
        prompt = <<~PROMPT
          Given the following document, generate #{questions_per_doc} question-answer pairs
          that can be answered using the document content.

          Document:
          #{content}

          Respond in JSON: {"pairs": [{"question": "...", "answer": "...", "context": "relevant excerpt"}]}
        PROMPT

        begin
          result = judge.call(prompt)
        rescue StandardError
          next # keep generating from remaining docs; individual failure should not abort the batch
        end

        extract_pairs(result).each do |pair|
          next unless valid_pair?(pair)

          dataset.add(
            question: pair["question"],
            answer: pair["answer"],
            context: [pair["context"].is_a?(String) && !pair["context"].empty? ? pair["context"] : content],
            ground_truth: pair["answer"]
          )
        end
      end
      dataset
    end

    # Expands a list of file/directory paths into a flat list of file paths.
    # Validates existence — missing paths raise an Error.
    #
    # @param paths [String, Array<String>]
    # @return [Array<String>] absolute-or-relative file paths, each verified to exist
    # @raise [EvalRuby::Error] if any path does not exist
    def self.expand_document_paths(paths)
      result = []
      Array(paths).each do |path|
        if File.directory?(path)
          result.concat(Dir.glob(File.join(path, "**/*")).select { |p| File.file?(p) }.sort)
        elsif File.file?(path)
          result << path
        else
          raise Error, "Document path does not exist: #{path}"
        end
      end
      result
    end

    def self.build_judge_for(llm)
      config = EvalRuby.configuration.dup
      config.judge_llm = llm
      case llm
      when :openai then Judges::OpenAI.new(config)
      when :anthropic then Judges::Anthropic.new(config)
      else raise Error, "Unknown LLM: #{llm}"
      end
    end
    private_class_method :build_judge_for

    def self.extract_pairs(result)
      return [] unless result.is_a?(Hash)
      pairs = result["pairs"]
      pairs.is_a?(Array) ? pairs : []
    end
    private_class_method :extract_pairs

    def self.valid_pair?(pair)
      pair.is_a?(Hash) &&
        pair["question"].is_a?(String) && !pair["question"].strip.empty? &&
        pair["answer"].is_a?(String) && !pair["answer"].strip.empty?
    end
    private_class_method :valid_pair?

    private_class_method def self.parse_array_field(value)
      return [] if value.nil? || value.empty?

      JSON.parse(value)
    rescue JSON::ParserError
      [value]
    end
  end
end
