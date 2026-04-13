# frozen_string_literal: true

module EvalRuby
  module Embedders
    # Abstract base class for text embedders.
    # Subclasses must implement {#call} to convert a batch of strings
    # into a batch of float vectors, and {#model} to surface the model
    # identifier used (shown in metric details).
    class Base
      # @param config [Configuration]
      def initialize(config)
        @config = config
      end

      # Embeds a batch of texts.
      #
      # @param texts [Array<String>] inputs to embed
      # @return [Array<Array<Float>>] one vector per input, in the same order
      def call(texts)
        raise NotImplementedError, "#{self.class}#call must be implemented"
      end

      # @return [String] model identifier (e.g. "text-embedding-3-small")
      def model
        raise NotImplementedError, "#{self.class}#model must be implemented"
      end
    end
  end
end
