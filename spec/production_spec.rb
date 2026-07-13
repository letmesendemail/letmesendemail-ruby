# frozen_string_literal: true

RSpec.describe 'Production behavior' do
  describe LetMeSendEmail::Config do
    it 'rejects unsafe API keys' do
      ['', ' test', "test\n"].each do |key|
        expect { LetMeSendEmail::Client.new(api_key: key) }.to raise_error(ArgumentError, /api_key/)
      end
    end

    it 'rejects invalid base URLs' do
      ['relative/path', 'ftp://example.com', 'https://user@example.com',
       'https://example.com?x=1', 'https://example.com#fragment'].each do |url|
        config = described_class.new('test')
        config.base_url = url
        expect { config.validate! }.to raise_error(ArgumentError, /base_url/)
      end
    end

    it 'rejects invalid timeouts and retry counts' do
      config = described_class.new('test')
      config.timeout_ms = 0
      expect { config.validate! }.to raise_error(ArgumentError, /timeout_ms/)

      config.timeout_ms = 1
      config.retries = 21
      expect { config.validate! }.to raise_error(ArgumentError, /retries/)
    end
  end

  describe LetMeSendEmail::Client do
    subject(:client) do
      config = LetMeSendEmail::Config.new('test')
      config.retries = 2
      described_class.new(config: config)
    end

    it 'encodes an identifier as one path segment' do
      expect(client.resource_path_segment('hello/world + café')).to eq('hello%2Fworld%20%2B%20caf%C3%A9')
    end

    it 'rejects empty, dot-segment, and control-character identifiers' do
      ['', ' ', '.', '..', "bad\nid"].each do |id|
        expect { client.resource_path_segment(id) }.to raise_error(ArgumentError)
      end
    end

    it 'retries safe requests deterministically without a wall-clock wait' do
      transport = instance_double(LetMeSendEmail::HttpTransport)
      allow(transport).to receive(:call).and_raise(LetMeSendEmail::NetworkError, 'offline')
      client.instance_variable_set(:@transport, transport)
      allow(client).to receive(:sleep)

      expect { client.request(:get, '/emails') }.to raise_error(LetMeSendEmail::NetworkError)
      expect(transport).to have_received(:call).exactly(3).times
      expect(client).to have_received(:sleep).twice
    end

    it 'does not retry a write without an idempotency key' do
      transport = instance_double(LetMeSendEmail::HttpTransport)
      allow(transport).to receive(:call).and_raise(LetMeSendEmail::NetworkError, 'offline')
      client.instance_variable_set(:@transport, transport)

      expect { client.request(:post, '/emails', body: {}) }.to raise_error(LetMeSendEmail::NetworkError)
      expect(transport).to have_received(:call).once
    end

    it 'allows write retries with an idempotency key' do
      transport = instance_double(LetMeSendEmail::HttpTransport)
      allow(transport).to receive(:call).and_raise(LetMeSendEmail::TimeoutError, 'timeout')
      client.instance_variable_set(:@transport, transport)
      allow(client).to receive(:sleep)

      expect do
        client.request(:post, '/emails', body: {}, extra_headers: { 'Idempotency-Key' => 'request_123' })
      end.to raise_error(LetMeSendEmail::TimeoutError)
      expect(transport).to have_received(:call).exactly(3).times
    end

    it 'never retries verification writes' do
      transport = instance_double(LetMeSendEmail::HttpTransport)
      allow(transport).to receive(:call).and_raise(LetMeSendEmail::TimeoutError, 'timeout')
      client.instance_variable_set(:@transport, transport)

      expect { client.emails.verify('person@example.com') }.to raise_error(LetMeSendEmail::TimeoutError)
      expect(transport).to have_received(:call).once
    end
  end

  describe LetMeSendEmail::HttpTransport do
    subject(:transport) { described_class.new(LetMeSendEmail::Config.new('test')) }

    it 'parses bounded delta-seconds and HTTP-date Retry-After values' do
      now = Time.utc(2026, 7, 12, 12, 0, 0)
      allow(Time).to receive(:now).and_return(now)

      expect(transport.send(:parse_retry_after, '120')).to eq(120)
      expect(transport.send(:parse_retry_after, (now + 60).httpdate)).to eq(60)
    end

    it 'rejects unusable Retry-After values' do
      ['0', '301', '-1', 'invalid', nil].each do |value|
        expect(transport.send(:parse_retry_after, value)).to be_nil
      end
    end

    it 'preserves structured rate-limit metadata and the raw body' do
      headers = {
        'retry-after' => '120', 'x-ratelimit-limit' => '100',
        'x-ratelimit-remaining' => '0', 'x-request-id' => 'request_123'
      }
      raw = '{"message":"Limited","name":"daily_quota_exceeded"}'
      body = JSON.parse(raw)
      error = transport.send(:error_from_status, 429, body, headers, raw)

      expect(error).to be_a(LetMeSendEmail::RateLimitError)
      expect(error.retry_after).to eq(120)
      expect(error.limit).to eq(100)
      expect(error.remaining).to eq(0)
      expect(error.request_id).to eq('request_123')
      expect(error.raw_body).to eq(raw)
    end

    it 'maps malformed successful JSON to ApiError' do
      expect { transport.send(:parse_response_body, 'not-json', 200, {}) }
        .to raise_error(LetMeSendEmail::ApiError, /invalid JSON/)
    end

    it 'rejects non-object successful JSON' do
      expect { transport.send(:parse_response_body, '[]', 200, {}) }
        .to raise_error(LetMeSendEmail::ApiError, /JSON object/)
    end
  end

  it 'rejects simultaneous after and before cursors' do
    client = LetMeSendEmail::Client.new(api_key: 'test')

    expect { client.contacts.list(after: 'one', before: 'two') }.to raise_error(ArgumentError, /cannot/)
  end
end
