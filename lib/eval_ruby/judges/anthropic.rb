# frozen_string_literal: true

require "net/http"
require "json"
require "uri"

module EvalRuby
  module Judges
    class Anthropic < Base
      API_URL = "https://api.anthropic.com/v1/messages"

      def call(prompt)
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
      end
    end
  end
end
