# frozen_string_literal: true

RSpec.describe LetMeSendEmail::Client do
  subject(:client) { described_class.new(api_key: 'test_key') }

  describe 'initialization' do
    it 'creates a client with an api key' do
      expect(client).to be_a(described_class)
    end

    it 'raises without an api key' do
      expect { described_class.new }.to raise_error(ArgumentError)
    end

    it 'has all resources accessible' do
      expect(client.emails).to be_a(LetMeSendEmail::Resources::Emails)
      expect(client.domains).to be_a(LetMeSendEmail::Resources::Domains)
      expect(client.contacts).to be_a(LetMeSendEmail::Resources::Contacts)
      expect(client.contact_categories).to be_a(LetMeSendEmail::Resources::ContactCategories)
      expect(client.email_topics).to be_a(LetMeSendEmail::Resources::EmailTopics)
    end
  end

  describe 'config' do
    it 'has default values' do
      config = LetMeSendEmail::Config.new('test')
      expect(config.base_url).to eq('https://letmesend.email/api/v1')
      expect(config.timeout_ms).to eq(30_000)
      expect(config.retries).to eq(0)
    end

    it 'allows overrides' do
      config = LetMeSendEmail::Config.new('test')
      config.base_url = 'https://custom.test/api'
      config.timeout_ms = 10_000
      config.retries = 3
      expect(config.base_url).to eq('https://custom.test/api')
      expect(config.timeout_ms).to eq(10_000)
      expect(config.retries).to eq(3)
    end
  end
end
