# frozen_string_literal: true

module EvalRuby
  module Metrics
    # Abstract base class for all evaluation metrics.
    # Subclasses must implement {#call}.
    class Base
      # @return [EvalRuby::Judges::Base, nil] the LLM judge instance
      attr_reader :judge

      # @param judge [EvalRuby::Judges::Base, nil] LLM judge for evaluation
      def initialize(judge: nil)
        @judge = judge
      end

      # Evaluates the metric.
      #
      # @param kwargs [Hash] metric-specific keyword arguments
      # @return [Hash{Symbol => Object}] must include :score and :details keys
      def call(**kwargs)
        raise NotImplementedError, "#{self.class}#call must be implemented"
      end
    end
  end
end
