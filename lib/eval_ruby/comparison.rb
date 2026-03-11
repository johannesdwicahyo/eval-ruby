# frozen_string_literal: true

module EvalRuby
  # Statistical comparison of two evaluation reports using paired t-tests.
  #
  # @example
  #   comparison = EvalRuby.compare(report_a, report_b)
  #   puts comparison.summary
  #   comparison.significant_improvements # => [:faithfulness]
  class Comparison
    # @return [Report] baseline report
    attr_reader :report_a

    # @return [Report] comparison report
    attr_reader :report_b

    # @param report_a [Report] baseline
    # @param report_b [Report] comparison
    def initialize(report_a, report_b)
      @report_a = report_a
      @report_b = report_b
    end

    # @return [String] formatted comparison table with deltas and p-values
    def summary
      lines = [
        format("%-20s | %-10s | %-10s | %-8s | %s", "Metric", "A", "B", "Delta", "p-value"),
        "-" * 70
      ]

      all_metrics.each do |metric|
        stats_a = @report_a.metric_stats[metric]
        stats_b = @report_b.metric_stats[metric]
        next unless stats_a && stats_b

        delta = stats_b[:mean] - stats_a[:mean]
        scores_a = @report_a.results.filter_map { |r| r.scores[metric] }
        scores_b = @report_b.results.filter_map { |r| r.scores[metric] }
        t_result = paired_t_test(scores_a, scores_b)
        sig = significance_marker(t_result[:p_value])

        lines << format(
          "%-20s | %-10.4f | %-10.4f | %+.4f  | %.4f %s",
          metric, stats_a[:mean], stats_b[:mean], delta, t_result[:p_value], sig
        )
      end

      lines.join("\n")
    end

    # Returns metrics where report_b is significantly better than report_a.
    #
    # @param alpha [Float] significance level (default 0.05)
    # @return [Array<Symbol>] metric names with significant improvements
    def significant_improvements(alpha: 0.05)
      all_metrics.select do |metric|
        scores_a = @report_a.results.filter_map { |r| r.scores[metric] }
        scores_b = @report_b.results.filter_map { |r| r.scores[metric] }
        next false if scores_a.empty? || scores_b.empty?

        t_result = paired_t_test(scores_a, scores_b)
        mean_b = scores_b.sum / scores_b.size.to_f
        mean_a = scores_a.sum / scores_a.size.to_f
        t_result[:p_value] < alpha && mean_b > mean_a
      end
    end

    private

    def all_metrics
      (@report_a.metric_stats.keys + @report_b.metric_stats.keys).uniq
    end

    def paired_t_test(scores_a, scores_b)
      n = [scores_a.length, scores_b.length].min
      return {t_stat: 0.0, p_value: 1.0, significant: false} if n < 2

      diffs = scores_a.first(n).zip(scores_b.first(n)).map { |a, b| a - b }
      mean_diff = diffs.sum / n.to_f
      std_diff = Math.sqrt(diffs.sum { |d| (d - mean_diff)**2 } / (n - 1).to_f)

      return {t_stat: 0.0, p_value: 1.0, significant: false} if std_diff.zero?

      t_stat = mean_diff / (std_diff / Math.sqrt(n))
      p_value = 2 * (1 - normal_cdf(t_stat.abs))
      {t_stat: t_stat, p_value: p_value, significant: p_value < 0.05}
    end

    def normal_cdf(x)
      0.5 * (1 + Math.erf(x / Math.sqrt(2)))
    end

    def significance_marker(p_value)
      if p_value < 0.001
        "***"
      elsif p_value < 0.01
        "**"
      elsif p_value < 0.05
        "*"
      else
        ""
      end
    end
  end
end
