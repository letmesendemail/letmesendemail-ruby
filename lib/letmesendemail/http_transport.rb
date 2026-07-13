# frozen_string_literal: true

require 'net/http'
require 'json'
require 'openssl'
require 'time'
require 'uri'

module LetMeSendEmail
  # Internal net/http transport.
  class HttpTransport
    MAX_RETRY_AFTER_SECONDS = 300

    def initialize(config)
      @config = config
    end

    def call(method, path, body: nil, extra_headers: {})
      uri = URI.parse("#{@config.base_url}/#{path.sub(%r{^/}, '')}")
      response = perform(uri, method, body, extra_headers)
      headers = response.each_header.to_h { |key, value| [key.downcase, value] }
      status = response.code.to_i
      raw_body = response.body.to_s
      parsed = parse_response_body(raw_body, status, headers)

      return Models.wrap(parsed) if status.between?(200, 299)

      raise error_from_status(status, parsed, headers, raw_body)
    rescue Net::OpenTimeout, Net::ReadTimeout, Net::WriteTimeout => e
      raise TimeoutError, e.message
    rescue SocketError, SystemCallError, IOError, OpenSSL::SSL::SSLError, Net::HTTPBadResponse => e
      raise NetworkError, e.message
    end

    private

    def perform(uri, method, body, extra_headers)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == 'https'
      timeout_seconds = @config.timeout_ms / 1000.0
      http.open_timeout = timeout_seconds
      http.read_timeout = timeout_seconds
      http.write_timeout = timeout_seconds if http.respond_to?(:write_timeout=)

      request = request_class(method).new(uri)
      request['Authorization'] = "Bearer #{@config.api_key}"
      request['Content-Type'] = 'application/json'
      request['Accept'] = 'application/json'
      request['User-Agent'] = "letmesendemail-ruby/#{LetMeSendEmail::VERSION}"
      extra_headers.each { |key, value| request[key] = value }
      request.body = JSON.generate(body) if body
      http.request(request)
    end

    def request_class(method)
      {
        get: Net::HTTP::Get,
        post: Net::HTTP::Post,
        put: Net::HTTP::Put,
        delete: Net::HTTP::Delete
      }.fetch(method) { raise ArgumentError, "unknown HTTP method: #{method}" }
    end

    def parse_response_body(raw_body, status, headers)
      return {} if raw_body.empty?

      parsed = JSON.parse(raw_body)
      return parsed if parsed.is_a?(Hash)

      raise_response_error('API response must be a JSON object.', status, headers, raw_body)
    rescue JSON::ParserError => e
      raise_response_error("API returned invalid JSON: #{e.message}", status, headers, raw_body)
    end

    def raise_response_error(message, status, headers, raw_body)
      raise ApiError.new(message, status_code: status, response_headers: headers, raw_body: raw_body)
    end

    def error_from_status(status, body, headers, raw_body)
      message = body['message'] || 'Unknown error.'
      keywords = error_keywords(status, body, headers, raw_body)

      case status
      when 400, 413, 422 then ValidationError.new(message, **keywords)
      when 401 then AuthenticationError.new(message, **keywords)
      when 403 then AuthorizationError.new(message, **keywords)
      when 404 then NotFoundError.new(message, **keywords)
      when 409 then ConflictError.new(message, **keywords)
      when 429 then rate_limit_error(message, keywords, headers)
      else ApiError.new(message, **keywords)
      end
    end

    def error_keywords(status, body, headers, raw_body)
      {
        status_code: status,
        api_code: body['name'],
        validation_errors: body['errors'],
        request_id: headers['x-request-id'],
        response_headers: headers,
        raw_body: raw_body
      }
    end

    def rate_limit_error(message, keywords, headers)
      RateLimitError.new(
        message,
        **keywords,
        retry_after: parse_retry_after(headers['retry-after']),
        limit: parse_integer(headers['x-ratelimit-limit']),
        remaining: parse_integer(headers['x-ratelimit-remaining']),
        reset_at: headers['x-ratelimit-reset']
      )
    end

    def parse_retry_after(value)
      return if value.nil?

      seconds = value.match?(/\A\d+\z/) ? value.to_i : (Time.httpdate(value) - Time.now).ceil
      seconds if seconds.between?(1, MAX_RETRY_AFTER_SECONDS)
    rescue ArgumentError
      nil
    end

    def parse_integer(value)
      Integer(value, exception: false)
    end
  end
end
