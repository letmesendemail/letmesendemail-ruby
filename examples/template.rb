# frozen_string_literal: true

require 'letmesendemail'

api_key = ENV.fetch('LETMESENDEMAIL_API_KEY')
raise 'LETMESENDEMAIL_API_KEY must not be empty' if api_key.empty?

client = LetMeSendEmail::Client.new(api_key: api_key)
result = client.emails.send_with_template(
  from: 'Acme <hello@example.com>',
  to: ['customer@example.net'],
  template_id: 'template_123',
  template_variables: [
    { key: 'CUSTOMER_NAME', type: 'string', value: 'Taylor' },
    { key: 'ORDER_NUMBER', type: 'number', value: 12_345 }
  ]
)
puts result['status']
