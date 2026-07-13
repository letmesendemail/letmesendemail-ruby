# frozen_string_literal: true

require 'uri'

module LetMeSendEmail
  # HTTP client and entry point for all API resources.
  class Client
    RETRYABLE_HTTP_STATUSES = [408, 500, 502, 503, 504].freeze
    SAFE_METHODS = %i[get delete].freeze
    MAX_RETRY_DELAY_SECONDS = 300
    BASE_RETRY_DELAY_SECONDS = 0.1

    # @return [Resources::Emails]
    attr_reader :emails
    # @return [Resources::Domains]
    attr_reader :domains
    # @return [Resources::Contacts]
    attr_reader :contacts
    # @return [Resources::ContactCategories]
    attr_reader :contact_categories
    # @return [Resources::EmailTopics]
    attr_reader :email_topics

    # @param api_key [String, nil]
    # @param config [Config, nil]
    # @raise [ArgumentError] when configuration is invalid
    def initialize(api_key: nil, config: nil)
      raise ArgumentError, 'provide api_key or config, not both' if api_key && config

      @config = config || Config.new(api_key || raise(ArgumentError, 'api_key is required'))
      raise ArgumentError, 'config must be a LetMeSendEmail::Config' unless @config.is_a?(Config)

      @config = @config.dup.validate!.freeze
      @transport = HttpTransport.new(@config)
      initialize_resources
    end

    # Performs an API request. Resource classes provide the primary public API.
    # @param method [Symbol]
    # @param path [String]
    # @param body [Hash, nil]
    # @param extra_headers [Hash]
    # @return [Models::Model]
    # @raise [Error]
    def request(method, path, body: nil, extra_headers: {})
      retry_eligible = retry_eligible?(method, extra_headers)
      max_attempts = retry_eligible ? @config.retries + 1 : 1
      last_error = nil

      max_attempts.times do |attempt|
        return @transport.call(method, path, body: body, extra_headers: extra_headers)
      rescue RateLimitError => e
        raise unless attempt < max_attempts - 1 && e.retry_after

        last_error = e
        sleep(e.retry_after)
      rescue NetworkError, TimeoutError => e
        raise unless attempt < max_attempts - 1

        last_error = e
        sleep(retry_delay(attempt))
      rescue ApiError => e
        raise unless RETRYABLE_HTTP_STATUSES.include?(e.status_code) && attempt < max_attempts - 1

        last_error = e
        sleep(retry_delay(attempt))
      end

      raise last_error
    end

    # Encodes an untrusted identifier as exactly one URL path segment.
    # @param id [String]
    # @return [String]
    # @raise [ArgumentError] when the identifier is empty or unsafe
    def resource_path_segment(id)
      raise ArgumentError, 'resource id must be a string' unless id.is_a?(String)

      value = id
      if value.empty? || value != value.strip || %w[. ..].include?(value) || value.match?(/[[:cntrl:]]/)
        raise ArgumentError, 'resource id must be non-empty and must not be a dot segment or contain unsafe whitespace'
      end

      URI::DEFAULT_PARSER.escape(value, /[^A-Za-z0-9\-._~]/)
    end

    private

    def initialize_resources
      @emails = Resources::Emails.new(self)
      @domains = Resources::Domains.new(self)
      @contacts = Resources::Contacts.new(self)
      @contact_categories = Resources::ContactCategories.new(self)
      @email_topics = Resources::EmailTopics.new(self)
    end

    def retry_eligible?(method, headers)
      return true if SAFE_METHODS.include?(method)

      key = headers['Idempotency-Key'] || headers['idempotency-key']
      %i[post put].include?(method) && key.is_a?(String) && !key.empty?
    end

    def retry_delay(attempt)
      base = [BASE_RETRY_DELAY_SECONDS * (2**attempt), MAX_RETRY_DELAY_SECONDS].min
      [base + (rand * base * 0.25), MAX_RETRY_DELAY_SECONDS].min
    end
  end
end
