# frozen_string_literal: true

require 'json'
require 'letmesendemail'

secret = ENV.fetch('LETMESENDEMAIL_WEBHOOK_SECRET')
raise 'LETMESENDEMAIL_WEBHOOK_SECRET must not be empty' if secret.empty?

headers = JSON.parse(ENV.fetch('LETMESENDEMAIL_WEBHOOK_HEADERS_JSON'))
raw_payload = $stdin.read
verified_payload = LetMeSendEmail::Webhooks.verify(raw_payload, headers, secret)
puts JSON.generate(verified_payload)
