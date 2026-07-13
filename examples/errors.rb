# frozen_string_literal: true

require 'letmesendemail'

api_key = ENV.fetch('LETMESENDEMAIL_API_KEY')
raise 'LETMESENDEMAIL_API_KEY must not be empty' if api_key.empty?

client = LetMeSendEmail::Client.new(api_key: api_key)

begin
  client.emails.get('email_123')
rescue LetMeSendEmail::ValidationError => e
  warn "Validation failed: #{e.validation_errors.inspect}"
rescue LetMeSendEmail::RateLimitError => e
  warn "Rate limited; retry after: #{e.retry_after.inspect}"
rescue LetMeSendEmail::Error => e
  warn "Request failed: #{e.message} (request #{e.request_id || 'unknown'})"
end
