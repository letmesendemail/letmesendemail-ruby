# Changelog

## 0.1.0 — 2026-07-13

- Initial Ruby SDK implementation for emails, domains, contacts, contact categories, and email topics.
- Structured API, network, timeout, rate-limit, and webhook errors.
- Validated client configuration, safe resource path encoding, conservative retries, and `Retry-After` support.
- Constant-time webhook signature verification with ordinary and Rack/CGI header support.
- Recursive response models with `to_h`, `as_json`, and standard JSON serialization.
- Fixture-backed tests, runnable examples, CI, comprehensive documentation, and RubyGems release guidance.
- Webhook verification tests use generic payload data without assuming undocumented
  event names or payload fields.
- Development dependencies constrain `parallel` to the Ruby 3.1-compatible 1.x
  series so the complete Ruby 3.1–4.0 CI matrix resolves consistently.
