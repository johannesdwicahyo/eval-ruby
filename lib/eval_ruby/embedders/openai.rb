# frozen_string_literal: true

require "net/http"
require "json"
require "uri"

module EvalRuby
  module Embedders
    # OpenAI embeddings backend.
    # Requires an API key via {Configuration#embedder_api_key} (or falls
    # back to {Configuration#api_key}). The default model is
    # +text-embedding-3-small+ (1536 dimensions).
    class OpenAI < Base
      API_URL = "https://api.openai.com/v1/embeddings"

      # @param config [Configuration]
      # @raise [EvalRuby::Error] if no API key is available
      def initialize(config)
        super
        @api_key = @config.embedder_api_key || @config.api_key
        if @api_key.nil? || @api_key.empty?
          raise EvalRuby::Error, "API key is required for embedder. Set via EvalRuby.configure { |c| c.embedder_api_key = '...' } or c.api_key = '...'"
        end
      end

      # @return [String] configured embedder model
      def model
        @config.embedder_model
      end

      # @param texts [Array<String>] inputs to embed
      # @return [Array<Array<Float>>] vectors in input order
      # @raise [EvalRuby::APIError] on non-success HTTP responses
      # @raise [EvalRuby::TimeoutError] after max retries
      def call(texts)
        retries = 0
        begin
          uri = URI(API_URL)
          request = Net::HTTP::Post.new(uri)
          request["Authorization"] = "Bearer #{@api_key}"
          request["Content-Type"] = "application/json"
          request.body = JSON.generate({input: texts, model: model})

          response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true,
                                     read_timeout: @config.timeout) do |http|
            http.request(request)
          end

          unless response.is_a?(Net::HTTPSuccess)
            raise APIError, "OpenAI embeddings API error: #{response.code} - #{response.body}"
          end

          parse_vectors(response.body)
        rescue Net::OpenTimeout, Net::ReadTimeout, Errno::ECONNRESET => e
          retries += 1
          if retries <= @config.max_retries
            sleep(2**(retries - 1))
            retry
          end
          raise EvalRuby::TimeoutError, "Embedder API failed after #{@config.max_retries} retries: #{e.message}"
        end
      end

      private

      def parse_vectors(body)
        parsed = JSON.parse(body)
        data = parsed["data"]
        raise InvalidResponseError, "Unexpected embeddings response shape: missing 'data'" unless data.is_a?(Array)

        # OpenAI returns data entries tagged with 'index' to preserve input order;
        # sort defensively in case the API ever reorders.
        data.sort_by { |entry| entry["index"].to_i }.map do |entry|
          vector = entry["embedding"]
          raise InvalidResponseError, "Embedding entry missing 'embedding' array" unless vector.is_a?(Array)
          vector
        end
      rescue JSON::ParserError => e
        raise InvalidResponseError, "Failed to parse embeddings response: #{e.message}"
      end
    end
  end
end
