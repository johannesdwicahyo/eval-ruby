# frozen_string_literal: true

module EvalRuby
  # Holds evaluation scores and details for a single sample.
  #
  # @example
  #   result = EvalRuby.evaluate(question: "...", answer: "...", context: [...])
  #   result.faithfulness  # => 0.95
  #   result.overall       # => 0.87
  class Result
    METRICS = %i[faithfulness relevance correctness context_precision context_recall].freeze

    # @return [Hash{Symbol => Float}] metric name to score mapping
    attr_reader :scores

    # @return [Hash{Symbol => Hash}] metric name to details mapping
    attr_reader :details

    # @param scores [Hash{Symbol => Float}]
    # @param details [Hash{Symbol => Hash}]
    def initialize(scores: {}, details: {})
      @scores = scores
      @details = details
    end

    METRICS.each do |metric|
      # @!method faithfulness
      #   @return [Float, nil] faithfulness score
      # @!method relevance
      #   @return [Float, nil] relevance score
      # @!method correctness
      #   @return [Float, nil] correctness score
      # @!method context_precision
      #   @return [Float, nil] context precision score
      # @!method context_recall
      #   @return [Float, nil] context recall score
      define_method(metric) { @scores[metric] }
    end

    # Computes a weighted average of all available scores.
    #
    # @param weights [Hash{Symbol => Float}, nil] custom weights per metric
    # @return [Float, nil] weighted average score, or nil if no scores available
    def overall(weights: nil)
      weights ||= METRICS.each_with_object({}) { |m, h| h[m] = 1.0 }
      available = @scores.select { |k, v| weights.key?(k) && v }
      return nil if available.empty?

      total_weight = available.sum { |k, _| weights[k] }
      available.sum { |k, v| v * weights[k] } / total_weight
    end

    # @return [Hash] scores plus overall
    def to_h
      @scores.merge(overall: overall)
    end

    # @return [String] human-readable summary
    def to_s
      lines = @scores.map { |k, v| "  #{k}: #{v&.round(4) || 'N/A'}" }
      lines << "  overall: #{overall&.round(4) || 'N/A'}"
      "EvalRuby::Result\n#{lines.join("\n")}"
    end
  end
end
