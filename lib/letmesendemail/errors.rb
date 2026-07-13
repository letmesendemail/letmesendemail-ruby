# frozen_string_literal: true

module LetMeSendEmail
  # Base class for all SDK failures.
  class Error < StandardError
    attr_reader :status_code, :api_code, :validation_errors, :request_id, :response_headers, :raw_body

    def initialize(message = nil, status_code: nil, api_code: nil,
                   validation_errors: nil, request_id: nil,
                   response_headers: nil, raw_body: nil)
      super(message)
      @status_code = status_code
      @api_code = api_code
      @validation_errors = validation_errors || {}
      @request_id = request_id
      @response_headers = response_headers || {}
      @raw_body = raw_body
    end
  end

  # An API response that does not have a more specific mapping.
  class ApiError < Error; end
  # HTTP 401 authentication failure.
  class AuthenticationError < Error; end
  # HTTP 403 authorization failure.
  class AuthorizationError < Error; end
  # HTTP 400, 413, or 422 validation failure.
  class ValidationError < Error; end

  # HTTP 429 failure with rate-limit metadata.
  class RateLimitError < Error
    attr_reader :retry_after, :limit, :remaining, :reset_at

    def initialize(message = nil, status_code: nil, api_code: nil,
                   validation_errors: nil, request_id: nil,
                   response_headers: nil, raw_body: nil,
                   retry_after: nil, limit: nil, remaining: nil, reset_at: nil)
      super(message, status_code: status_code, api_code: api_code,
                     validation_errors: validation_errors, request_id: request_id,
                     response_headers: response_headers, raw_body: raw_body)
      @retry_after = retry_after
      @limit = limit
      @remaining = remaining
      @reset_at = reset_at
    end
  end

  # HTTP 404 failure.
  class NotFoundError < Error; end
  # HTTP 409 failure.
  class ConflictError < Error; end
  # Connection, socket, TLS, or response transport failure.
  class NetworkError < Error; end
  # HTTP connection, read, or write timeout.
  class TimeoutError < Error; end
  # Invalid webhook request or signature.
  class WebhookVerificationError < Error; end
  # Invalid webhook signing secret.
  class WebhookSigningError < Error; end
end
