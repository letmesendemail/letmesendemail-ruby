# letmesend.email SDK for Ruby

The official Ruby client for the [letmesend.email](https://letmesend.email/) API. It supports Ruby 3.1+, uses `net/http`, and has no runtime HTTP dependency.

## Installation

Add the gem to your bundle:

```bash
bundle add letmesendemail
```

Or install it directly:

```bash
gem install letmesendemail
```

## Quick Start

```ruby
require "letmesendemail"

api_key = ENV.fetch("LETMESENDEMAIL_API_KEY")
raise "LETMESENDEMAIL_API_KEY must not be empty" if api_key.empty?

client = LetMeSendEmail::Client.new(api_key: api_key)

begin
  email = client.emails.send(
    from: "Acme <hello@example.com>",
    to: ["customer@example.net"],
    subject: "Welcome",
    html: "<p>Thanks for joining.</p>",
    text: "Thanks for joining."
  )
  puts email["id"]
rescue LetMeSendEmail::Error => e
  warn "Email request failed: #{e.message}"
end
```

## Configuration

```ruby
config = LetMeSendEmail::Config.new(api_key)
config.base_url = "https://letmesend.email/api/v1"
config.timeout_ms = 30_000
config.retries = 2

client = LetMeSendEmail::Client.new(config: config)
```

The default timeout is 30,000 milliseconds and retries default to zero. Retry counts must be between 0 and 20. Safe requests retry network errors, timeouts, HTTP 408/500/502/503/504, and HTTP 429 only when `Retry-After` is valid and no more than 300 seconds. Email sends require an idempotency key to retry; verification calls are never retried.

## Emails

```ruby
sent = client.emails.send(
  from: "Acme <hello@example.com>",
  to: ["customer@example.net"],
  subject: "Receipt",
  text: "Your receipt is ready.",
  idempotency_key: "receipt-order-123"
)

templated = client.emails.send_with_template(
  from: "Acme <hello@example.com>",
  to: ["customer@example.net"],
  template_id: "template_123",
  template_variables: [
    { key: "CUSTOMER_NAME", type: "string", value: "Taylor" },
    { key: "ORDER_NUMBER", type: "number", value: 12_345 }
  ]
)

verification = client.emails.verify("customer@example.net")
email = client.emails.get("email_123")
```

## Domains

```ruby
domains = client.domains.list(per_page: 20)
domain = client.domains.get("domain_123")
verification = client.domains.verify("example.com")
```

## Contacts

```ruby
contact = client.contacts.create(
  email: "customer@example.net",
  first_name: "Taylor",
  categories: ["category_123"]
)

client.contacts.update(contact["id"], first_name: "Morgan")
client.contacts.get(contact["id"])
client.contacts.list(per_page: 20)
client.contacts.delete(contact["id"])
```

## Contact Categories

```ruby
category = client.contact_categories.create(name: "Customers")
client.contact_categories.get(category["id"])
client.contact_categories.list(per_page: 20)
client.contact_categories.update(category["id"], name: "Active customers")
client.contact_categories.delete(category["id"])
```

## Email Topics

```ruby
topic = client.email_topics.create(
  name: "Product updates",
  slug: "product-updates",
  public: true,
  auto_subscribe: false
)
client.email_topics.get(topic["id"])
client.email_topics.list(per_page: 20)
client.email_topics.update(topic["id"], description: "Product news")
client.email_topics.delete(topic["id"])
```

## Pagination

All list resources accept `per_page`, `after`, and `before`. Do not send `after` and `before` together.

```ruby
first = client.emails.list(per_page: 20)
items = first["data"]

if first["pagination"]["has_more"] && !items.empty?
  next_page = client.emails.list(per_page: 20, after: items.last["id"])
end

unless items.empty?
  previous_page = client.emails.list(per_page: 20, before: items.first["id"])
end
```

Retain cursor history in your application for Back/Previous navigation. The API does not provide arbitrary page-number jumps.

## Model Serialization

API operations return `LetMeSendEmail::Models::Model`. It supports hash-style access, recursive `to_h`, Rails-compatible `as_json`, and standard JSON encoding.

```ruby
contact = client.contacts.get("contact_123")
database_attributes = contact.to_h
json = JSON.generate(contact)
```

`to_h` returns a defensive recursive copy. It preserves API field names and `nil` values while excluding client configuration, credentials, and transport state.

## Error Handling

```ruby
begin
  client.emails.get("email_123")
rescue LetMeSendEmail::ValidationError => e
  warn e.validation_errors.inspect
rescue LetMeSendEmail::AuthenticationError, LetMeSendEmail::AuthorizationError => e
  warn e.message
rescue LetMeSendEmail::RateLimitError => e
  warn "Retry after #{e.retry_after.inspect} seconds"
rescue LetMeSendEmail::NetworkError, LetMeSendEmail::TimeoutError => e
  warn e.message
rescue LetMeSendEmail::Error => e
  warn "#{e.message}; request_id=#{e.request_id.inspect}"
end
```

## Webhooks

Always verify the exact, unmodified request body before using the parsed payload.

```ruby
require "json"

secret = ENV.fetch("LETMESENDEMAIL_WEBHOOK_SECRET")
raise "LETMESENDEMAIL_WEBHOOK_SECRET must not be empty" if secret.empty?
raw_request_body = $stdin.read
request_headers = JSON.parse(ENV.fetch("LETMESENDEMAIL_WEBHOOK_HEADERS_JSON"))

begin
  payload = LetMeSendEmail::Webhooks.verify(raw_request_body, request_headers, secret)
  puts payload.inspect
rescue LetMeSendEmail::WebhookVerificationError,
       LetMeSendEmail::WebhookSigningError => e
  warn "Webhook rejected: #{e.message}"
end
```

The verifier accepts ordinary headers and Rack/CGI `HTTP_WEBHOOK_*` keys. The default timestamp tolerance is 300 seconds.

## Testing

The SDK does not make network requests until a resource method is called. Use application-level dependency boundaries around the client in tests. To work on the gem:

```bash
bundle exec rubocop
bundle exec rspec
```

## Version Support

Ruby 3.1, 3.2, 3.3, 3.4, and 4.0 are tested in CI.

## Changelog

See the [changelog](CHANGELOG.md).

## Full Documentation

See the [complete Ruby SDK manual](docs/docs.md).
