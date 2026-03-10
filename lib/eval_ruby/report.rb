# frozen_string_literal: true

require "csv"
require "json"

module EvalRuby
  class Report
    attr_reader :results, :duration, :samples

    def initialize(results:, samples: [], duration: nil)
      @results = results
      @samples = samples
      @duration = duration
    end

    def summary
      lines = []
      metric_stats.each do |metric, stats|
        lines << format("%-20s %.4f (+/- %.4f)", "#{metric}:", stats[:mean], stats[:std])
      end
      lines << ""
      lines << "Total: #{@results.size} samples | Duration: #{format_duration}"
      lines.join("\n")
    end

    def metric_stats
      return {} if @results.empty?

      all_metrics = @results.flat_map { |r| r.scores.keys }.uniq
      all_metrics.each_with_object({}) do |metric, hash|
        values = @results.filter_map { |r| r.scores[metric] }
        next if values.empty?

        mean = values.sum / values.size.to_f
        denominator = values.size > 1 ? (values.size - 1).to_f : 1.0
        variance = values.sum { |v| (v - mean)**2 } / denominator
        std = Math.sqrt(variance)
        hash[metric] = {mean: mean, std: std, min: values.min, max: values.max, count: values.size}
      end
    end

    def worst(n = 5)
      @results.sort_by { |r| r.overall || 0.0 }.first(n)
    end

    def failures(threshold: nil)
      threshold ||= EvalRuby.configuration.default_threshold
      @results.select { |r| (r.overall || 0.0) < threshold }
    end

    def to_csv(path)
      return if @results.empty?

      all_metrics = @results.flat_map { |r| r.scores.keys }.uniq
      CSV.open(path, "w") do |csv|
        csv << ["sample_index"] + all_metrics.map(&:to_s) + ["overall"]
        @results.each_with_index do |result, i|
          row = [i] + all_metrics.map { |m| result.scores[m]&.round(4) } + [result.overall&.round(4)]
          csv << row
        end
      end
    end

    def to_json(path)
      data = @results.each_with_index.map do |result, i|
        {index: i, scores: result.scores, overall: result.overall, sample: @samples[i]}
      end
      File.write(path, JSON.pretty_generate({results: data, summary: metric_stats}))
    end

    private

    def format_duration
      return "N/A" unless @duration

      if @duration < 60
        "#{@duration.round(1)}s"
      else
        "#{(@duration / 60).floor}m #{(@duration % 60).round(1)}s"
      end
    end
  end
end
