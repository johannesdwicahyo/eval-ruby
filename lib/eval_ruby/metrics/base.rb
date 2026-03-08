# frozen_string_literal: true

module EvalRuby
  module Metrics
    class Base
      attr_reader :judge

      def initialize(judge: nil)
        @judge = judge
      end

      def call(**kwargs)
        raise NotImplementedError, "#{self.class}#call must be implemented"
      end
    end
  end
end
