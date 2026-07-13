# frozen_string_literal: true

require 'securerandom'
require 'letmesendemail'

api_key = ENV.fetch('LETMESENDEMAIL_API_KEY')
raise 'LETMESENDEMAIL_API_KEY must not be empty' if api_key.empty?

client = LetMeSendEmail::Client.new(api_key: api_key)
result = client.emails.send(
  from: 'Acme <hello@example.com>',
  to: ['customer@example.net'],
  subject: 'Receipt',
  text: 'Your receipt is ready.',
  idempotency_key: SecureRandom.uuid
)
puts result['id']
