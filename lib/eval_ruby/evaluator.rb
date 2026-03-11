# frozen_string_literal: true

module EvalRuby
  # Runs all configured metrics on a given question/answer/context tuple.
  #
  # @example
  #   evaluator = EvalRuby::Evaluator.new
  #   result = evaluator.evaluate(question: "...", answer: "...", context: [...])
  class Evaluator
    # @param config [Configuration] configuration to use
    def initialize(config = EvalRuby.configuration)
      @config = config
      @judge = build_judge(config)
    end

    # Evaluates an LLM response across quality metrics.
    #
    # @param question [String] the input question
    # @param answer [String] the LLM-generated answer
    # @param context [Array<String>] retrieved context chunks
    # @param ground_truth [String, nil] expected correct answer
    # @return [Result]
    def evaluate(question:, answer:, context: [], ground_truth: nil)
      scores = {}
      details = {}

      # LLM-as-judge metrics
      faith = Metrics::Faithfulness.new(judge: @judge).call(answer: answer, context: context)
      scores[:faithfulness] = faith[:score]
      details[:faithfulness] = faith[:details]

      rel = Metrics::Relevance.new(judge: @judge).call(question: question, answer: answer)
      scores[:relevance] = rel[:score]
      details[:relevance] = rel[:details]

      cp = Metrics::ContextPrecision.new(judge: @judge).call(question: question, context: context)
      scores[:context_precision] = cp[:score]
      details[:context_precision] = cp[:details]

      if ground_truth
        corr = Metrics::Correctness.new(judge: @judge).call(answer: answer, ground_truth: ground_truth)
        scores[:correctness] = corr[:score]
        details[:correctness] = corr[:details]

        cr = Metrics::ContextRecall.new(judge: @judge).call(context: context, ground_truth: ground_truth)
        scores[:context_recall] = cr[:score]
        details[:context_recall] = cr[:details]
      end

      Result.new(scores: scores, details: details)
    end

    # Evaluates retrieval quality using IR metrics.
    #
    # @param question [String] the input question
    # @param retrieved [Array<String>] retrieved document IDs
    # @param relevant [Array<String>] ground-truth relevant document IDs
    # @return [RetrievalResult]
    def evaluate_retrieval(question:, retrieved:, relevant:)
      RetrievalResult.new(retrieved: retrieved, relevant: relevant)
    end

    private

    def build_judge(config)
      case config.judge_llm
      when :openai
        Judges::OpenAI.new(config)
      when :anthropic
        Judges::Anthropic.new(config)
      else
        raise Error, "Unknown judge LLM: #{config.judge_llm}"
      end
    end
  end

  # Holds retrieval evaluation results with IR metric accessors.
  #
  # @example
  #   result = EvalRuby.evaluate_retrieval(question: "...", retrieved: [...], relevant: [...])
  #   result.precision_at_k(5) # => 0.6
  #   result.mrr               # => 1.0
  class RetrievalResult
    # @param retrieved [Array<String>] retrieved document IDs in ranked order
    # @param relevant [Array<String>] ground-truth relevant document IDs
    def initialize(retrieved:, relevant:)
      @retrieved = retrieved
      @relevant = relevant
    end

    # @param k [Integer] number of top results to consider
    # @return [Float] precision at k
    def precision_at_k(k)
      Metrics::PrecisionAtK.new.call(retrieved: @retrieved, relevant: @relevant, k: k)
    end

    # @param k [Integer] number of top results to consider
    # @return [Float] recall at k
    def recall_at_k(k)
      Metrics::RecallAtK.new.call(retrieved: @retrieved, relevant: @relevant, k: k)
    end

    # @return [Float] mean reciprocal rank
    def mrr
      Metrics::MRR.new.call(retrieved: @retrieved, relevant: @relevant)
    end

    # @param k [Integer, nil] number of top results (nil for all)
    # @return [Float] normalized discounted cumulative gain
    def ndcg(k: nil)
      Metrics::NDCG.new.call(retrieved: @retrieved, relevant: @relevant, k: k)
    end

    # @return [Float] 1.0 if any relevant doc is retrieved, 0.0 otherwise
    def hit_rate
      @retrieved.any? { |doc| @relevant.include?(doc) } ? 1.0 : 0.0
    end

    # @return [Hash{Symbol => Float}] all retrieval metrics
    def to_h
      {
        precision_at_k: precision_at_k(@retrieved.length),
        recall_at_k: recall_at_k(@retrieved.length),
        mrr: mrr,
        ndcg: ndcg,
        hit_rate: hit_rate
      }
    end
  end
end
