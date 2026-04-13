# frozen_string_literal: true

module EvalRuby
  module Metrics
    # Cosine similarity between an answer and its ground truth via an
    # injected embedder. A judge-free alternative to {Correctness} when
    # you want fast, deterministic, reference-based scoring — ideal for
    # chatbot regression testing.
    #
    # @example
    #   embedder = EvalRuby::Embedders::OpenAI.new(EvalRuby.configuration)
    #   metric = EvalRuby::Metrics::SemanticSimilarity.new(embedder: embedder)
    #   metric.call(answer: "Paris is in France", ground_truth: "Paris, France")
    #   # => { score: 0.91, details: { cosine: 0.91, model: "text-embedding-3-small" } }
    class SemanticSimilarity < Base
      # @return [EvalRuby::Embedders::Base, nil] the embedder instance
      attr_reader :embedder

      # @param embedder [EvalRuby::Embedders::Base] required for this metric
      # @param judge [EvalRuby::Judges::Base, nil] unused by this metric; accepted
      #   only for interface compatibility with {Metrics::Base}
      def initialize(embedder: nil, judge: nil)
        super(judge: judge)
        @embedder = embedder
      end

      # @param answer [String] candidate text (typically the model's answer)
      # @param ground_truth [String] reference text
      # @return [Hash] +:score+ (Float 0.0–1.0) and +:details+ (Hash)
      # @raise [EvalRuby::Error] if no embedder is configured
      def call(answer:, ground_truth:, **_kwargs)
        raise EvalRuby::Error, "SemanticSimilarity requires an embedder. Pass `embedder:` in the constructor." unless @embedder

        if answer.to_s.strip.empty? || ground_truth.to_s.strip.empty?
          return {score: 0.0, details: {reason: :empty_input}}
        end

        vectors = @embedder.call([answer.to_s, ground_truth.to_s])
        unless vectors.is_a?(Array) && vectors.length == 2
          raise EvalRuby::Error, "Embedder returned #{vectors.is_a?(Array) ? vectors.length : vectors.class} vectors; expected 2"
        end

        cosine = cosine_similarity(vectors[0], vectors[1])

        {
          score: cosine.clamp(0.0, 1.0),
          details: {cosine: cosine, model: @embedder.model}
        }
      end

      private

      def cosine_similarity(a, b)
        raise EvalRuby::Error, "Embedding vector dimension mismatch: #{a.length} vs #{b.length}" unless a.length == b.length

        dot = 0.0
        norm_a = 0.0
        norm_b = 0.0
        a.each_with_index do |x, i|
          y = b[i]
          dot += x * y
          norm_a += x * x
          norm_b += y * y
        end

        return 0.0 if norm_a.zero? || norm_b.zero?

        dot / (Math.sqrt(norm_a) * Math.sqrt(norm_b))
      end
    end
  end
end
