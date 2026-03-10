# frozen_string_literal: true

require "net/http"
require "json"
require "uri"

module EvalRuby
  module Judges
    class OpenAI < Base
      API_URL = "https://api.openai.com/v1/chat/completions"

      def initialize(config)
        super
        raise EvalRuby::Error, "API key is required. Set via EvalRuby.configure { |c| c.api_key = '...' }" if @config.api_key.nil? || @config.api_key.empty?
      end

      def call(prompt)
        retries = 0
        begin
          uri = URI(API_URL)
          request = Net::HTTP::Post.new(uri)
          request["Authorization"] = "Bearer #{@config.api_key}"
          request["Content-Type"] = "application/json"
          request.body = JSON.generate({
            model: @config.judge_model,
            messages: [{role: "user", content: prompt}],
            temperature: 0.0,
            response_format: {type: "json_object"}
          })

          response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true,
                                     read_timeout: @config.timeout) do |http|
            http.request(request)
          end

          unless response.is_a?(Net::HTTPSuccess)
            raise Error, "OpenAI API error: #{response.code} - #{response.body}"
          end

          body = JSON.parse(response.body)
          content = body.dig("choices", 0, "message", "content")
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
