# frozen_string_literal: true

module EvalRuby
  class Result
    METRICS = %i[faithfulness relevance correctness context_precision context_recall].freeze

    attr_reader :scores, :details

    def initialize(scores: {}, details: {})
      @scores = scores
      @details = details
    end

    METRICS.each do |metric|
      define_method(metric) { @scores[metric] }
    end

    def overall(weights: nil)
      weights ||= METRICS.each_with_object({}) { |m, h| h[m] = 1.0 }
      available = @scores.select { |k, v| weights.key?(k) && v }
      return nil if available.empty?

      total_weight = available.sum { |k, _| weights[k] }
      available.sum { |k, v| v * weights[k] } / total_weight
    end

    def to_h
      @scores.merge(overall: overall)
    end

    def to_s
      lines = @scores.map { |k, v| "  #{k}: #{v&.round(4) || 'N/A'}" }
      lines << "  overall: #{overall&.round(4) || 'N/A'}"
      "EvalRuby::Result\n#{lines.join("\n")}"
    end
  end
end
