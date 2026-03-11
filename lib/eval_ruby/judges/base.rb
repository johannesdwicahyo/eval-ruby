# frozen_string_literal: true

module EvalRuby
  module Judges
    # Abstract base class for LLM judges.
    # Subclasses must implement {#call} to send prompts to an LLM and parse JSON responses.
    class Base
      # @param config [Configuration]
      def initialize(config)
        @config = config
      end

      # Sends a prompt to the LLM and returns parsed JSON.
      #
      # @param prompt [String] the evaluation prompt
      # @return [Hash, nil] parsed JSON response
      def call(prompt)
        raise NotImplementedError, "#{self.class}#call must be implemented"
      end

      private

      # Extracts and parses the first JSON object from text.
      #
      # @param text [String] raw LLM response text
      # @return [Hash, nil] parsed JSON or nil if not found
      def parse_json_response(text)
        match = text.match(/\{[^{}]*(?:\{[^{}]*\}[^{}]*)*\}/m)
        return nil unless match

        JSON.parse(match[0])
      rescue JSON::ParserError
        nil
      end
    end
  end
end
