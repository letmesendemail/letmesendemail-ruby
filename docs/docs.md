# letmesend.email SDK for Ruby

## Overview

The `letmesendemail` gem is the official Ruby client for the letmesend.email API. It provides resource-oriented email, domain, contact, contact-category, and email-topic operations; structured errors; cursor pagination; conservative retries; and webhook verification.

API responses are returned as `LetMeSendEmail::Models::Model` values with hash-style access and recursive serialization.

## Requirements

- Ruby 3.1 or newer
- Bundler or RubyGems
- A letmesend.email API key

The SDK uses Ruby's `net/http` and `json` libraries. Its only declared runtime gem is `base64`.

## Installation

With Bundler:

```bash
bundle add letmesendemail
```

Or install the gem directly:

```bash
gem install letmesendemail
```

Load the package with:

```ruby
require "letmesendemail"
```

## Authentication

Create an API key in your letmesend.email account and expose it to the application as `LETMESENDEMAIL_API_KEY`. Do not commit API keys or place them in source code.

```ruby
api_key = ENV.fetch("LETMESENDEMAIL_API_KEY")
raise "LETMESENDEMAIL_API_KEY must not be empty" if api_key.empty?

client = LetMeSendEmail::Client.new(api_key: api_key)
```

The SDK sends the key as a Bearer token. It rejects empty keys, surrounding whitespace, and control characters.

## Quick Start

```ruby
require "letmesendemail"

api_key = ENV.fetch("LETMESENDEMAIL_API_KEY")
raise "LETMESENDEMAIL_API_KEY must not be empty" if api_key.empty?

client = LetMeSendEmail::Client.new(api_key: api_key)

begin
  result = client.emails.send(
    from: "Acme <hello@example.com>",
    to: ["customer@example.net"],
    subject: "Welcome",
    html: "<p>Thanks for joining.</p>",
    text: "Thanks for joining."
  )
  puts "Accepted email #{result['id']} with status #{result['status']}"
rescue LetMeSendEmail::Error => e
  warn "Email request failed: #{e.message}"
end
```

## Client Configuration

For custom settings, create a configuration object before creating the client:

```ruby
config = LetMeSendEmail::Config.new(api_key)
config.base_url = "https://letmesend.email/api/v1"
config.timeout_ms = 30_000
config.retries = 2

client = LetMeSendEmail::Client.new(config: config)
```

| Option | Default | Behavior |
|---|---:|---|
| `api_key` | Required | Bearer token; must be a non-empty safe string. |
| `base_url` | `https://letmesend.email/api/v1` | Absolute HTTP or HTTPS URL without credentials, query, or fragment. Trailing slashes are removed. |
| `timeout_ms` | `30000` | Positive timeout in milliseconds applied to connection, read, and write phases. |
| `retries` | `0` | Additional attempts, from 0 through 20. |

Requests use `letmesendemail-ruby/<version>` as their User-Agent. Supplying both `api_key:` and `config:` is rejected.
The client takes an immutable snapshot of the validated configuration when it is created; later changes to the original configuration object do not affect that client.

### Retry behavior

When retries are enabled, GET and DELETE requests may retry. POST and PUT requests require a non-empty `Idempotency-Key`; email and domain verification calls do not retry. The SDK retries network failures, timeouts, HTTP 408, 500, 502, 503, and 504. HTTP 429 retries only when `Retry-After` is a positive delta-seconds value or future HTTP date no more than 300 seconds away.

Ordinary retry delay starts at 100 milliseconds, doubles per retry, adds random jitter from zero through 25% of that delay, and caps at 300 seconds. A valid `Retry-After` delay is used exactly without jitter.

## Emails

Email operations are available through `client.emails`. Every method returns a `LetMeSendEmail::Models::Model`.

### Send an Email

```ruby
result = client.emails.send(
  from: "Acme <hello@example.com>",
  to: ["customer@example.net"],
  subject: "Your receipt",
  html: "<p>Your receipt is ready.</p>",
  text: "Your receipt is ready.",
  type: "transactional",
  event_name: "receipt.created",
  email_topic_id: "topic_123",
  reply_to: ["support@example.com"],
  cc: ["accounts@example.com"],
  bcc: ["archive@example.com"],
  headers: { "X-Order-ID" => "order_123" },
  idempotency_key: "receipt-order-123"
)

puts result["id"]
puts result["status"]
puts result["emails"].inspect
puts result["restricted_emails"].inspect
```

`from`, `to`, and `subject` are required. Provide at least one of `html` or `text` as required by your email workflow. `type` supports `broadcast` and `transactional`. Address arrays accept plain addresses or display-name forms such as `Taylor <customer@example.net>`.

### Send with a Template

```ruby
result = client.emails.send_with_template(
  from: "Acme <hello@example.com>",
  to: ["customer@example.net"],
  template_id: "template_123",
  subject: "Order update",
  template_variables: [
    { key: "CUSTOMER_NAME", type: "string", value: "Taylor" },
    { key: "ORDER_NUMBER", type: "number", value: 12_345 }
  ],
  idempotency_key: "template-order-123"
)
```

`from`, `to`, and `template_id` are required. Template variables are arrays of hashes containing `key`, `type`, and `value`. Number values must be Ruby numeric values rather than numeric strings.

Template sending also accepts `type`, `event_name`, `email_topic_id`, `reply_to`, `cc`, `bcc`, `headers`, `attachments`, and `idempotency_key`.

### Attachments

An attachment uses `name` and exactly one of `path` or Base64-encoded `content`. Optional fields are `mime`, `content_id`, and `content_disposition`. `content_disposition` supports `attachment` and `inline`. Use `content_id` to reference an inline attachment from HTML.

```ruby
require "base64"

encoded_content = Base64.strict_encode64("Example attachment\n".b)

result = client.emails.send(
  from: "Acme <hello@example.com>",
  to: ["customer@example.net"],
  subject: "Your file",
  text: "The requested file is attached.",
  attachments: [{
    name: "message.txt",
    content: encoded_content,
    mime: "text/plain",
    content_disposition: "attachment"
  }]
)
```

A remote attachment can use `path` instead:

```ruby
attachments = [{
  name: "invoice.pdf",
  path: "https://files.example.com/invoice.pdf",
  mime: "application/pdf",
  content_disposition: "attachment"
}]
```

Do not send `path` and `content` together. `download_url`, attachment `id`, and `size` are response fields and must not be used in requests.

### Idempotency

Pass a stable, unique idempotency key when a send might be retried:

```ruby
result = client.emails.send(
  from: "Acme <hello@example.com>",
  to: ["customer@example.net"],
  subject: "Receipt",
  text: "Your receipt is ready.",
  idempotency_key: "receipt-order-123"
)
```

The key is sent in the `Idempotency-Key` header and is never placed in the JSON response model.

### Verify an Email Address

```ruby
verification = client.emails.verify("customer@example.net")
puts verification["status"]
puts verification["score"]
puts verification["domain_exists"]
puts verification["valid_syntax"]
```

Verification results can also contain `disposable`, `role_based`, `has_mailbox`, `receive_email`, `mx_records`, and `belongs_to`. Verification is deliberately never retried.

### List Emails

```ruby
first = client.emails.list(per_page: 20)
items = first["data"]
pagination = first["pagination"]

if pagination["has_more"] && !items.empty?
  next_page = client.emails.list(per_page: 20, after: items.last["id"])
end

unless items.empty?
  previous_page = client.emails.list(per_page: 20, before: items.first["id"])
end
```

Email list items include `id`, `status`, `subject`, `event_name`, `type`, `created_at`, `sent_at`, `recipients_count`, and `attachments_count`.

### Get an Email

```ruby
email = client.emails.get("email_123")

email["recipients"].each do |recipient|
  puts "#{recipient['email_address']}: #{recipient['status']}"
end

email["attachments"].each do |attachment|
  puts "#{attachment['name']}: #{attachment['download_url']}"
end
```

Detailed recipients expose delivery, open, click, bounce, complaint, failure, suppression, and timestamp fields returned by the API. Detailed attachments include `id`, `name`, `mime`, `content_id`, `content_disposition`, `size`, and `download_url`.

## Domains

```ruby
first = client.domains.list(per_page: 20)
items = first["data"]

if first["pagination"]["has_more"] && !items.empty?
  next_page = client.domains.list(per_page: 20, after: items.last["id"])
end

unless items.empty?
  previous_page = client.domains.list(per_page: 20, before: items.first["id"])
end

domain = client.domains.get("domain_123")
verification = client.domains.verify("example.com")
```

`list` returns domain models and pagination. `get(id)` returns `id`, `domain_name`, `status`, and `created_at`. `verify(domain)` returns the verification status and is never retried.

## Contacts

```ruby
contact = client.contacts.create(
  email: "customer@example.net",
  first_name: "Taylor",
  last_name: "Morgan",
  phone: "+14165550123",
  is_globally_unsubscribed: false,
  categories: ["category_123"],
  email_topics: ["topic_123"]
)

client.contacts.update(
  contact["id"],
  first_name: "Alex",
  categories: ["category_456"],
  sync_categories: true
)

stored = client.contacts.get(contact["id"])
client.contacts.delete(contact["id"])
```

`update` also supports `last_name`, `phone`, `is_globally_unsubscribed`, `email_topics`, and `sync_email_topics`.

Contact pagination:

```ruby
first = client.contacts.list(per_page: 20)
items = first["data"]
next_page = client.contacts.list(per_page: 20, after: items.last["id"]) if first["pagination"]["has_more"] && !items.empty?
previous_page = client.contacts.list(per_page: 20, before: items.first["id"]) unless items.empty?
```

## Contact Categories

```ruby
category = client.contact_categories.create(name: "Customers", slug: "customers")
category = client.contact_categories.get(category["id"])
client.contact_categories.update(category["id"], name: "Active customers", slug: "active-customers")
client.contact_categories.delete(category["id"])
```

Contact-category pagination:

```ruby
first = client.contact_categories.list(per_page: 20)
items = first["data"]
next_page = client.contact_categories.list(per_page: 20, after: items.last["id"]) if first["pagination"]["has_more"] && !items.empty?
previous_page = client.contact_categories.list(per_page: 20, before: items.first["id"]) unless items.empty?
```

## Email Topics

```ruby
topic = client.email_topics.create(
  name: "Product updates",
  slug: "product-updates",
  auto_subscribe: false,
  public: true,
  description: "News about product improvements",
  domain_id: "domain_123"
)

topic = client.email_topics.get(topic["id"])
client.email_topics.update(
  topic["id"],
  name: "Product news",
  description: "Important product news",
  public: true,
  auto_subscribe: false
)
client.email_topics.delete(topic["id"])
```

When `domain_id` is supplied, the request sends it as `domain: { id: domain_id }`. Responses may include a nested domain with `id` and `name`.

Email-topic pagination:

```ruby
first = client.email_topics.list(per_page: 20)
items = first["data"]
next_page = client.email_topics.list(per_page: 20, after: items.last["id"]) if first["pagination"]["has_more"] && !items.empty?
previous_page = client.email_topics.list(per_page: 20, before: items.first["id"]) unless items.empty?
```

## Model Serialization and Database Storage

Every API response, list envelope, pagination object, list item, and nested response hash is a `LetMeSendEmail::Models::Model`. Arrays contain recursively wrapped models. Access fields with string or symbol keys:

```ruby
contact = client.contacts.get("contact_123")
puts contact["email"]
puts contact[:email]
```

Use `to_h` for a recursive defensive copy suitable for persistence:

```ruby
contact = client.contacts.get("contact_123")
database_record = contact.to_h

# Pass database_record to your application's persistence layer.
database_record["synced_at"] = Time.now.utc.iso8601
```

Use the standard JSON library directly:

```ruby
require "json"

json_document = JSON.generate(contact)
restored = JSON.parse(json_document)
```

`as_json` returns the same plain representation for Rails integrations. Field names remain API snake-case strings. Nested models and arrays convert recursively; `nil`, booleans, numbers, identifiers, enum strings, and ISO 8601 timestamp strings are preserved. `to_h` returns new hashes, arrays, and strings so mutating the result does not mutate the SDK model. Client configuration, API keys, authorization headers, webhook secrets, retries, and transport state are never part of response models.

Request inputs are ordinary Ruby hashes and arrays, so they are already compatible with `JSON.generate`. The SDK omits optional keyword fields that are not supplied.

## Pagination

`emails`, `domains`, `contacts`, `contact_categories`, and `email_topics` list methods accept `per_page:`, `after:`, and `before:`. A list response contains:

- `data`: the current array of models
- `pagination.has_more`: whether a next page is available
- `pagination.per_page`: requested page size
- `pagination.fetched`: number fetched
- `pagination.total`: total matching records

Use the final item ID as `after` and the first item ID as `before`. Always guard an empty collection, check `has_more` before moving forward, and never pass `after` with `before`. The client rejects that combination before network I/O.

The API does not expose arbitrary page-number jumps or `has_previous`. Retain cursor history in the application when implementing Back/Previous navigation. The SDK returns one page per call and does not auto-paginate.

## Errors and Exceptions

All SDK errors inherit from `LetMeSendEmail::Error`:

| Error | Meaning |
|---|---|
| `ValidationError` | HTTP 400, 413, or 422 |
| `AuthenticationError` | HTTP 401 |
| `AuthorizationError` | HTTP 403 |
| `NotFoundError` | HTTP 404 |
| `ConflictError` | HTTP 409 |
| `RateLimitError` | HTTP 429 |
| `ApiError` | Other API errors or malformed success responses |
| `NetworkError` | Connection, TLS, socket, or response transport failure |
| `TimeoutError` | Connection, read, or write timeout |
| `WebhookVerificationError` | Invalid webhook headers, timestamp, signature, or JSON |
| `WebhookSigningError` | Missing or invalid webhook secret |

```ruby
begin
  client.emails.get("email_123")
rescue LetMeSendEmail::ValidationError => e
  warn e.validation_errors.inspect
rescue LetMeSendEmail::AuthenticationError, LetMeSendEmail::AuthorizationError => e
  warn e.message
rescue LetMeSendEmail::NotFoundError, LetMeSendEmail::ConflictError => e
  warn "#{e.message} (HTTP #{e.status_code})"
rescue LetMeSendEmail::RateLimitError => e
  warn "Retry after: #{e.retry_after.inspect}"
rescue LetMeSendEmail::NetworkError, LetMeSendEmail::TimeoutError => e
  warn "Transport failure: #{e.message}"
rescue LetMeSendEmail::ApiError => e
  warn "API failure: #{e.message}"
end
```

`Error` exposes `status_code`, `api_code`, `validation_errors`, `request_id`, `response_headers`, and `raw_body`. `RateLimitError` additionally exposes `retry_after`, `limit`, `remaining`, and `reset_at`. Treat `raw_body` and headers as diagnostic data; avoid logging message content or other sensitive application data.

## Timeouts, Cancellation, and Retries

The configured positive `timeout_ms` value applies separately to the `net/http` connect, response-read, and request-write phases. Ruby `net/http` does not expose a separate SDK cancellation token. Applications can stop waiting by cancelling or terminating their own task/thread according to their framework's conventions.

Retries are disabled by default. Configure them explicitly and use idempotency keys for sends. A timeout or network failure on a non-idempotent write without a key is returned immediately because the server may have accepted the request.

For HTTP 429, inspect `RateLimitError#retry_after`. Missing, malformed, zero, negative, past, or greater-than-300-second values are exposed as `nil` and are not automatically retried.

## Webhooks

Verification requires the exact raw request body and these headers:

- `webhook-id`
- `webhook-log-id`
- `webhook-timestamp`
- `webhook-signature`

The secret is Base64 encoded and may use the `whsec_` prefix. Only `v1` signatures are accepted; multiple signatures are supported and unknown versions are ignored. The default timestamp tolerance is 300 seconds in either direction.

```ruby
require "json"
require "letmesendemail"

secret = ENV.fetch("LETMESENDEMAIL_WEBHOOK_SECRET")
raise "LETMESENDEMAIL_WEBHOOK_SECRET must not be empty" if secret.empty?

raw_body = $stdin.read
headers = JSON.parse(ENV.fetch("LETMESENDEMAIL_WEBHOOK_HEADERS_JSON"))

begin
  verified_payload = LetMeSendEmail::Webhooks.verify(raw_body, headers, secret)
  puts verified_payload.inspect
rescue LetMeSendEmail::WebhookVerificationError,
       LetMeSendEmail::WebhookSigningError => e
  warn "Webhook rejected: #{e.message}"
end
```

Rack/CGI header keys such as `HTTP_WEBHOOK_ID` are normalized automatically. The verifier checks the HMAC in constant time, then parses the payload and requires a JSON object. It does not assume any event names or payload schema.

## Framework Integration

The client is a plain Ruby object and can be registered in the dependency container used by Rails, Hanami, Sinatra, or another framework. Create it once per application configuration, or per tenant when API keys differ. Do not expose the client or its API key through model serialization or logs.

## Testing

This gem does not provide a fake client. Place the client behind an application service boundary and inject a test double for that service in application tests. To contribute to the gem:

```bash
bundle install
bundle exec rubocop --parallel
bundle exec rspec
find examples -name "*.rb" -print0 | xargs -0 -n1 ruby -c
gem build letmesendemail.gemspec
```

## Runtime Support

Ruby 3.1, 3.2, 3.3, 3.4, and 4.0 are tested in CI. The gemspec requires Ruby 3.1 or newer.

## Upgrading

Review the [changelog](../CHANGELOG.md) before upgrading. Install an explicit
version when your application requires reproducible dependency resolution.

## Getting Help

- [letmesend.email documentation](https://letmesend.email/docs)
- [Issue tracker](https://github.com/letmesendemail/letmesendemail-ruby/issues)
- [Changelog](../CHANGELOG.md)
