# frozen_string_literal: true

require 'openssl'
require 'base64'
require 'json'

RSpec.describe LetMeSendEmail::Webhooks do
  def make_data(payload, secret, timestamp = nil)
    ts = timestamp || Time.now.to_i
    raw = JSON.generate(payload)
    raw_secret = secret.start_with?('whsec_') ? secret[6..] : secret
    decoded = Base64.strict_decode64(raw_secret)

    to_sign = "web_123.web_log_123.#{ts}.#{raw}"
    # Canonical: base64(raw_digest)
    raw_digest = OpenSSL::HMAC.digest('SHA256', decoded, to_sign)
    sig = Base64.strict_encode64(raw_digest)

    {
      payload: raw,
      headers: {
        'webhook-id' => 'web_123',
        'webhook-log-id' => 'web_log_123',
        'webhook-timestamp' => ts.to_s,
        'webhook-signature' => "v1,#{sig}"
      }
    }
  end

  describe '.verify' do
    it 'verifies a valid signature' do
      secret = Base64.strict_encode64('0123456789abcdef0123456789abcdef')
      data = make_data({ sample: 'value' }, secret)
      result = described_class.verify(data[:payload], data[:headers], secret)
      expect(result['sample']).to eq('value')
    end

    it 'verifies with whsec_ prefix' do
      raw = Base64.strict_encode64('0123456789abcdef0123456789abcdef')
      prefixed = "whsec_#{raw}"
      data = make_data({ sample: 'value' }, prefixed)
      result = described_class.verify(data[:payload], data[:headers], prefixed)
      expect(result['sample']).to eq('value')
    end

    it 'fails with wrong secret' do
      s1 = Base64.strict_encode64('a' * 32)
      s2 = Base64.strict_encode64('b' * 32)
      data = make_data({ sample: 'value' }, s1)
      expect { described_class.verify(data[:payload], data[:headers], s2) }
        .to raise_error(LetMeSendEmail::WebhookVerificationError)
    end

    it 'fails with expired timestamp' do
      secret = Base64.strict_encode64('a' * 32)
      old_ts = Time.now.to_i - 600
      data = make_data({ sample: 'value' }, secret, old_ts)
      expect { described_class.verify(data[:payload], data[:headers], secret) }
        .to raise_error(LetMeSendEmail::WebhookVerificationError, /too old/)
    end

    it 'fails with future timestamp' do
      secret = Base64.strict_encode64('a' * 32)
      future_ts = Time.now.to_i + 600
      data = make_data({ sample: 'value' }, secret, future_ts)
      expect { described_class.verify(data[:payload], data[:headers], secret) }
        .to raise_error(LetMeSendEmail::WebhookVerificationError, /too far/)
    end

    it 'fails with missing headers' do
      expect { described_class.verify('{}', {}, 'secret') }
        .to raise_error(LetMeSendEmail::WebhookVerificationError)
    end

    it 'fails with non-numeric timestamp' do
      secret = Base64.strict_encode64('a' * 32)
      headers = {
        'webhook-id' => 'id',
        'webhook-log-id' => 'log',
        'webhook-timestamp' => 'not-a-number',
        'webhook-signature' => 'v1,sig'
      }
      expect { described_class.verify('{}', headers, secret) }
        .to raise_error(LetMeSendEmail::WebhookVerificationError, /not numeric/)
    end

    it 'supports multiple signatures' do
      secret = Base64.strict_encode64('a' * 32)
      data = make_data({ sample: 'value' }, secret)
      data[:headers]['webhook-signature'] = "v1,badsig #{data[:headers]['webhook-signature']}"
      result = described_class.verify(data[:payload], data[:headers], secret)
      expect(result['sample']).to eq('value')
    end

    it 'ignores unknown versions' do
      secret = Base64.strict_encode64('a' * 32)
      data = make_data({ sample: 'value' }, secret)
      data[:headers]['webhook-signature'] = "v2,ignored #{data[:headers]['webhook-signature']}"
      result = described_class.verify(data[:payload], data[:headers], secret)
      expect(result['sample']).to eq('value')
    end

    it 'supports case-insensitive headers' do
      secret = Base64.strict_encode64('a' * 32)
      data = make_data({ sample: 'value' }, secret)
      lower = data[:headers].transform_keys(&:downcase)
      result = described_class.verify(data[:payload], lower, secret)
      expect(result['sample']).to eq('value')
    end

    it 'supports Rack HTTP-prefixed headers' do
      secret = Base64.strict_encode64('a' * 32)
      data = make_data({ sample: 'value' }, secret)
      rack_headers = data[:headers].to_h { |key, value| ["HTTP_#{key.upcase.tr('-', '_')}", value] }

      result = described_class.verify(data[:payload], rack_headers, secret)
      expect(result['sample']).to eq('value')
    end

    it 'rejects invalid input and tolerance' do
      expect { described_class.verify(nil, {}, 'secret') }
        .to raise_error(LetMeSendEmail::WebhookVerificationError)
      expect { described_class.verify('{}', [], 'secret') }
        .to raise_error(LetMeSendEmail::WebhookVerificationError)
      expect { described_class.verify('{}', {}, 'secret', tolerance: -1) }
        .to raise_error(LetMeSendEmail::WebhookVerificationError)
    end

    it 'rejects empty and whitespace secrets' do
      ['', '   ', nil].each do |secret|
        expect { described_class.verify('{}', {}, secret) }
          .to raise_error(LetMeSendEmail::WebhookSigningError)
      end
    end

    it 'fails with malformed JSON' do
      secret = Base64.strict_encode64('a' * 32)
      ts = Time.now.to_i
      to_sign = "web_123.web_log_123.#{ts}.not-json"
      raw_digest = OpenSSL::HMAC.digest('SHA256', Base64.strict_decode64(secret), to_sign)
      sig = Base64.strict_encode64(raw_digest)

      expect do
        described_class.verify('not-json', {
                                 'webhook-id' => 'web_123',
                                 'webhook-log-id' => 'web_log_123',
                                 'webhook-timestamp' => ts.to_s,
                                 'webhook-signature' => "v1,#{sig}"
                               }, secret)
      end.to raise_error(LetMeSendEmail::WebhookVerificationError)
    end

    it 'fails with un-decodable secret' do
      ts = Time.now.to_i
      expect do
        described_class.verify('{}', {
                                 'webhook-id' => 'id',
                                 'webhook-log-id' => 'log',
                                 'webhook-timestamp' => ts.to_s,
                                 'webhook-signature' => 'v1,sig'
                               }, 'not-base64!!!?')
      end.to raise_error(LetMeSendEmail::WebhookSigningError)
    end
  end
end
