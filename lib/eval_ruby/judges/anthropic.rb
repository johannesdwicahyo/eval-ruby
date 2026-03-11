# frozen_string_literal: true

require "net/http"
require "json"
require "uri"

module EvalRuby
  module Judges
    # Anthropic-based LLM judge using the Messages API.
    # Requires an API key set via {Configuration#api_key}.
    class Anthropic < Base
      API_URL = "https://api.anthropic.com/v1/messages"

      # @param config [Configuration]
      # @raise [EvalRuby::Error] if API key is missing
      def initialize(config)
        super
        raise EvalRuby::Error, "API key is required. Set via EvalRuby.configure { |c| c.api_key = '...' }" if @config.api_key.nil? || @config.api_key.empty?
      end

      # @param prompt [String] the evaluation prompt
      # @return [Hash, nil] parsed JSON response
      # @raise [EvalRuby::Error] on API errors
      # @raise [EvalRuby::TimeoutError] after max retries
      def call(prompt)
        retries = 0
        begin
          uri = URI(API_URL)
          request = Net::HTTP::Post.new(uri)
          request["x-api-key"] = @config.api_key
          request["anthropic-version"] = "2023-06-01"
          request["Content-Type"] = "application/json"
          request.body = JSON.generate({
            model: @config.judge_model,
            max_tokens: 4096,
            messages: [{role: "user", content: prompt}],
            temperature: 0.0
          })

          response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true,
                                     read_timeout: @config.timeout) do |http|
            http.request(request)
          end

          unless response.is_a?(Net::HTTPSuccess)
            raise Error, "Anthropic API error: #{response.code} - #{response.body}"
          end

          body = JSON.parse(response.body)
          content = body.dig("content", 0, "text")
          parse_json_response(content)
        rescue Net::OpenTimeout, Net::ReadTimeout, Errno::ECONNRESET => e
          retries += 1
          if retries <= @config.max_retries
            sleep(2 ** (retries - 1))
            retry
          end
          raise EvalRuby::TimeoutError, "Judge API failed after #{@config.max_retries} retries: #{e.message}"
        end
      end
    end
  end
end
