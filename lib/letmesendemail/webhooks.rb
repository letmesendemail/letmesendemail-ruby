# frozen_string_literal: true

require 'openssl'
require 'base64'
require 'json'

module LetMeSendEmail
  # Verifies signatures on raw letmesend.email webhook requests.
  module Webhooks
    REQUIRED_HEADERS = %w[webhook-id webhook-log-id webhook-timestamp webhook-signature].freeze
    DEFAULT_TOLERANCE = 300

    module_function

    # Verifies a webhook signature before parsing the JSON payload.
    # @param payload [String] exact raw request body
    # @param headers [Hash] request headers
    # @param secret [String] Base64 secret, optionally prefixed with +whsec_+
    # @param tolerance [Integer] allowed timestamp skew in seconds
    # @return [Hash] verified JSON object
    # @raise [WebhookVerificationError, WebhookSigningError]
    def verify(payload, headers, secret, tolerance: DEFAULT_TOLERANCE)
      validate_inputs!(payload, headers, secret, tolerance)
      extracted = extract_headers(headers)
      validate_timestamp!(extracted['webhook-timestamp'], tolerance)
      expected = expected_signature(payload, extracted, secret)
      validate_signature!(extracted['webhook-signature'], expected)
      parse_payload(payload)
    end

    # Normalizes Rack/CGI and ordinary HTTP header hashes.
    # @param headers [Hash]
    # @return [Hash]
    def resolve_headers(headers)
      headers.each_with_object({}) do |(key, value), result|
        normalized = key.to_s.downcase.sub(/\Ahttp_/, '').tr('_', '-')
        result[normalized] = value.to_s
      end
    end

    def validate_inputs!(payload, headers, secret, tolerance)
      raise WebhookVerificationError, 'Webhook payload must be a string.' unless payload.is_a?(String)
      raise WebhookVerificationError, 'Webhook headers must be a hash.' unless headers.is_a?(Hash)
      unless tolerance.is_a?(Integer) && tolerance >= 0
        raise WebhookVerificationError, 'Webhook tolerance must be zero or greater.'
      end
      return if secret.is_a?(String) && !secret.empty? && secret == secret.strip

      raise WebhookSigningError, 'Webhook secret must be a non-empty string.'
    end
    private_class_method :validate_inputs!

    def extract_headers(headers)
      resolved = resolve_headers(headers)
      REQUIRED_HEADERS.to_h do |header|
        value = resolved[header]
        raise WebhookVerificationError, "Missing required webhook header: #{header}." if value.nil? || value.empty?

        [header, value]
      end
    end
    private_class_method :extract_headers

    def validate_timestamp!(timestamp_string, tolerance)
      raise WebhookVerificationError, 'Webhook timestamp is not numeric.' unless timestamp_string.match?(/\A\d+\z/)

      timestamp = timestamp_string.to_i
      now = Time.now.to_i
      raise WebhookVerificationError, 'Webhook timestamp must be a positive integer.' unless timestamp.positive?
      raise WebhookVerificationError, 'Webhook timestamp is too old.' if timestamp < now - tolerance
      return unless timestamp > now + tolerance

      raise WebhookVerificationError, 'Webhook timestamp is too far in the future.'
    end
    private_class_method :validate_timestamp!

    def expected_signature(payload, headers, secret)
      raw_secret = secret.start_with?('whsec_') ? secret[6..] : secret
      decoded_secret = Base64.strict_decode64(raw_secret)
      raise WebhookSigningError, 'Webhook secret could not be decoded.' if decoded_secret.empty?

      signed = "#{headers['webhook-id']}.#{headers['webhook-log-id']}.#{headers['webhook-timestamp']}.#{payload}"
      Base64.strict_encode64(OpenSSL::HMAC.digest('SHA256', decoded_secret, signed))
    rescue ArgumentError
      raise WebhookSigningError, 'Webhook secret could not be decoded.'
    end
    private_class_method :expected_signature

    def validate_signature!(signature_header, expected)
      matched = signature_header.split.any? do |entry|
        version, candidate = entry.split(',', 2)
        version == 'v1' && candidate&.bytesize == expected.bytesize &&
          OpenSSL.fixed_length_secure_compare(candidate, expected)
      end
      raise WebhookVerificationError, 'No matching webhook signature found.' unless matched
    end
    private_class_method :validate_signature!

    def parse_payload(payload)
      parsed = JSON.parse(payload)
      raise WebhookVerificationError, 'Webhook payload must be a JSON object.' unless parsed.is_a?(Hash)

      parsed
    rescue JSON::ParserError
      raise WebhookVerificationError, 'Webhook payload is not valid JSON.'
    end
    private_class_method :parse_payload
  end
end
