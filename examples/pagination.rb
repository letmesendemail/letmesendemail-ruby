# frozen_string_literal: true

require 'letmesendemail'

api_key = ENV.fetch('LETMESENDEMAIL_API_KEY')
raise 'LETMESENDEMAIL_API_KEY must not be empty' if api_key.empty?

client = LetMeSendEmail::Client.new(api_key: api_key)
first_page = client.emails.list(per_page: 20)
items = first_page['data']

if first_page['pagination']['has_more'] && !items.empty?
  next_page = client.emails.list(per_page: 20, after: items.last['id'])
  puts "Next page contains #{next_page['data'].length} emails"
end

unless items.empty?
  previous_page = client.emails.list(per_page: 20, before: items.first['id'])
  puts "Previous page contains #{previous_page['data'].length} emails"
end
