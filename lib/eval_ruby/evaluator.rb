# frozen_string_literal: true

module EvalRuby
  class Evaluator
    def initialize(config = EvalRuby.configuration)
      @config = config
      @judge = build_judge(config)
    end

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

  class RetrievalResult
    def initialize(retrieved:, relevant:)
      @retrieved = retrieved
      @relevant = relevant
    end

    def precision_at_k(k)
      Metrics::PrecisionAtK.new.call(retrieved: @retrieved, relevant: @relevant, k: k)
    end

    def recall_at_k(k)
      Metrics::RecallAtK.new.call(retrieved: @retrieved, relevant: @relevant, k: k)
    end

    def mrr
      Metrics::MRR.new.call(retrieved: @retrieved, relevant: @relevant)
    end

    def ndcg(k: nil)
      Metrics::NDCG.new.call(retrieved: @retrieved, relevant: @relevant, k: k)
    end

    def hit_rate
      @retrieved.any? { |doc| @relevant.include?(doc) } ? 1.0 : 0.0
    end

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
