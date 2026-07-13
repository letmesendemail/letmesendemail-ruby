# frozen_string_literal: true

require 'base64'
require 'letmesendemail'

api_key = ENV.fetch('LETMESENDEMAIL_API_KEY')
raise 'LETMESENDEMAIL_API_KEY must not be empty' if api_key.empty?

content = Base64.strict_encode64("Example attachment\n".b)
client = LetMeSendEmail::Client.new(api_key: api_key)
result = client.emails.send(
  from: 'Acme <hello@example.com>',
  to: ['customer@example.net'],
  subject: 'Your file',
  text: 'The requested file is attached.',
  attachments: [{
    name: 'message.txt', content: content, mime: 'text/plain',
    content_disposition: 'attachment'
  }]
)
puts result['id']
