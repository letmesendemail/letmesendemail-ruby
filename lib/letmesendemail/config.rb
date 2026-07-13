# frozen_string_literal: true

require 'uri'

module LetMeSendEmail
  # Validated client configuration.
  class Config
    DEFAULT_BASE_URL = 'https://letmesend.email/api/v1'
    DEFAULT_TIMEOUT_MS = 30_000
    DEFAULT_RETRIES = 0
    MAX_RETRIES = 20

    attr_reader :base_url
    attr_accessor :api_key, :timeout_ms, :retries

    # @param api_key [String] API bearer token
    def initialize(api_key)
      @api_key = api_key
      @base_url = DEFAULT_BASE_URL
      @timeout_ms = DEFAULT_TIMEOUT_MS
      @retries = DEFAULT_RETRIES
    end

    # @param url [String] absolute API base URL
    # @return [String]
    def base_url=(url)
      @base_url = url.to_s.sub(%r{/+\z}, '')
    end

    # Validates and normalizes configuration before use.
    # @return [self]
    # @raise [ArgumentError] for unsafe or unsupported configuration
    def validate!
      validate_api_key!
      validate_base_url!
      validate_timeout!
      validate_retries!
      @api_key = api_key.dup.freeze
      @base_url = base_url.dup.freeze
      self
    end

    private

    def validate_api_key!
      return if api_key.is_a?(String) && !api_key.empty? && api_key == api_key.strip && !api_key.match?(/[[:cntrl:]]/)

      raise ArgumentError, 'api_key must be a non-empty string without surrounding whitespace or control characters'
    end

    def validate_base_url!
      uri = URI.parse(base_url)
      unless valid_base_uri?(uri)
        raise ArgumentError,
              'base_url must be an absolute HTTP(S) URL without credentials, query, or fragment'
      end

      self.base_url = base_url
    rescue URI::InvalidURIError
      raise ArgumentError, 'base_url must be an absolute HTTP(S) URL without credentials, query, or fragment'
    end

    def valid_base_uri?(uri)
      uri.is_a?(URI::HTTP) && %w[http https].include?(uri.scheme) && uri.host &&
        !uri.userinfo && !uri.query && !uri.fragment
    end

    def validate_timeout!
      return if timeout_ms.is_a?(Numeric) && timeout_ms.positive?

      raise ArgumentError, 'timeout_ms must be greater than zero'
    end

    def validate_retries!
      return if retries.is_a?(Integer) && retries.between?(0, MAX_RETRIES)

      raise ArgumentError, "retries must be an integer between 0 and #{MAX_RETRIES}"
    end
  end
end
