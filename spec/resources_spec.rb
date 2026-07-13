# frozen_string_literal: true

require 'net/http'
require 'json'

RSpec.describe 'Resources' do
  let(:api_key) { 'test_key' }
  let(:client) { LetMeSendEmail::Client.new(api_key: api_key) }

  # A helper that stubs Net::HTTP to return a canned response
  def stub_net_http(status_code, body, headers: {})
    response = instance_double(
      Net::HTTPResponse,
      code: status_code.to_s,
      body: JSON.generate(body),
      each_header: headers
    )
    allow(response).to receive(:[]).and_return(nil)
    allow_any_instance_of(Net::HTTP).to receive(:request).and_return(response)
    response
  end

  # ── Emails ──

  describe 'emails.send' do
    it 'sends and returns parsed response' do
      resp_body = { 'id' => 'e1', 'status' => 'accepted', 'emails' => ['j@e.com'], 'restricted_emails' => [] }
      stub_net_http(200, resp_body)

      result = client.emails.send(from: 'a@b.com', to: ['c@d.com'], subject: 'Hi')

      expect(result['id']).to eq('e1')
      expect(result['status']).to eq('accepted')
      expect(result['emails']).to eq(['j@e.com'])
    end

    it 'builds authenticated JSON with the SDK User-Agent and idempotency key' do
      response = instance_double(Net::HTTPResponse, code: '200', body: '{"id":"email_123"}', each_header: {})
      captured = nil
      allow_any_instance_of(Net::HTTP).to receive(:request) do |_http, request|
        captured = request
        response
      end

      client.emails.send(
        from: 'sender@example.com', to: ['customer@example.net'], subject: 'Hello',
        text: 'Hello', idempotency_key: 'request_123'
      )

      expect(captured.path).to eq('/api/v1/emails')
      expect(captured['Authorization']).to eq('Bearer test_key')
      expect(captured['User-Agent']).to eq("letmesendemail-ruby/#{LetMeSendEmail::VERSION}")
      expect(captured['Idempotency-Key']).to eq('request_123')
      expect(JSON.parse(captured.body)['text']).to eq('Hello')
    end
  end

  describe 'emails.verify' do
    it 'returns verification fields' do
      resp_body = { 'email' => 'j@e.com', 'score' => 40, 'status' => 'valid', 'domain_exists' => true,
                    'valid_syntax' => true, 'belongs_to' => 'j@gmail.com' }
      stub_net_http(200, resp_body)

      result = client.emails.verify('j@e.com')

      expect(result['domain_exists']).to be true
      expect(result['valid_syntax']).to be true
      expect(result['belongs_to']).to eq('j@gmail.com')
    end
  end

  describe 'emails.list' do
    it 'returns paginated data' do
      resp_body = {
        'data' => [{ 'id' => 'e1', 'status' => 'sent', 'subject' => 'Hi', 'type' => 'transactional',
                     'created_at' => '2026-01-01T00:00:00Z', 'recipients_count' => 1, 'attachments_count' => 0 }],
        'pagination' => { 'has_more' => false, 'per_page' => 10, 'fetched' => 1, 'total' => 1 }
      }
      stub_net_http(200, resp_body)

      result = client.emails.list

      expect(result['data'].size).to eq(1)
      expect(result['pagination']['has_more']).to be false
      expect(result['pagination']['total']).to eq(1)
    end
  end

  # ── Domains ──

  describe 'domains.list' do
    it 'returns typed domain list' do
      resp_body = { 'data' => [{ 'id' => 'd1', 'domain_name' => 'example.com', 'status' => 'verified',
                                 'created_at' => '2026-01-01T00:00:00Z' }],
                    'pagination' => { 'has_more' => false, 'per_page' => 20, 'fetched' => 1, 'total' => 1 } }
      stub_net_http(200, resp_body)

      result = client.domains.list

      expect(result['data'][0]['domain_name']).to eq('example.com')
    end
  end

  describe 'domains.verify' do
    it 'returns status' do
      stub_net_http(200, { 'status' => 'verified' })
      result = client.domains.verify('example.com')
      expect(result['status']).to eq('verified')
    end
  end

  # ── Contacts ──

  describe 'contacts' do
    it 'create returns contact' do
      stub_net_http(200, { 'id' => 'c1', 'email' => 'j@e.com', 'first_name' => 'John' })
      result = client.contacts.create(email: 'j@e.com')
      expect(result['first_name']).to eq('John')
    end

    it 'delete returns status' do
      stub_net_http(200, { 'status' => 'success' })
      result = client.contacts.delete('c1')
      expect(result['status']).to eq('success')
    end
  end

  # ── Contact Categories ──

  describe 'contact_categories' do
    it 'create returns item' do
      stub_net_http(200, { 'id' => 'cat1', 'name' => 'Test', 'slug' => 'test' })
      result = client.contact_categories.create(name: 'Test')
      expect(result['name']).to eq('Test')
      expect(result['slug']).to eq('test')
    end
  end

  # ── Email Topics ──

  describe 'email_topics' do
    it 'create returns topic' do
      stub_net_http(200, { 'id' => 't1', 'name' => 'Updates', 'slug' => 'updates',
                           'auto_subscribe' => true, 'created_at' => '2026-01-01T00:00:00Z' })
      result = client.email_topics.create(name: 'Updates', slug: 'updates')
      expect(result['name']).to eq('Updates')
      expect(result['auto_subscribe']).to be true
    end
  end

  # ── Errors ──

  describe 'error mapping' do
    it '401 raises AuthenticationError' do
      stub_net_http(401, { 'message' => 'Unauthorized', 'name' => 'unauth' })
      expect { client.emails.list }.to raise_error(LetMeSendEmail::AuthenticationError)
    end

    it '422 raises ValidationError with fields' do
      stub_net_http(422, { 'message' => 'Invalid', 'errors' => { 'email' => ['Required'] } })
      expect { client.emails.send(from: '', to: [], subject: '') }
        .to raise_error(LetMeSendEmail::ValidationError)
    end

    it '404 raises NotFoundError' do
      stub_net_http(404, { 'message' => 'Not found' })
      expect { client.emails.get('nonexistent') }.to raise_error(LetMeSendEmail::NotFoundError)
    end

    it '429 raises RateLimitError with retry_after' do
      stub_net_http(429, { 'message' => 'Limited' })
      expect { client.emails.list }.to raise_error(LetMeSendEmail::RateLimitError)
    end
  end
end
