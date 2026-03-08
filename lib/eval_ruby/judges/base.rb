# frozen_string_literal: true

module EvalRuby
  module Judges
    class Base
      def initialize(config)
        @config = config
      end

      def call(prompt)
        raise NotImplementedError, "#{self.class}#call must be implemented"
      end

      private

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
