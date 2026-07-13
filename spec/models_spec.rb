# frozen_string_literal: true

require 'json'

RSpec.describe LetMeSendEmail::Models::Model do
  subject(:model) do
    described_class.new(
      'id' => 'contact_123',
      'phone' => nil,
      'categories' => [{ 'id' => 'category_123', 'name' => 'Customers' }],
      'pagination' => { 'has_more' => false, 'total' => 1 }
    )
  end

  it 'provides hash-style access to recursively wrapped models' do
    expect(model['id']).to eq('contact_123')
    expect(model[:categories].first).to be_a(described_class)
    expect(model['pagination']['has_more']).to be(false)
  end

  it 'returns a recursive defensive copy from to_h' do
    plain = model.to_h
    plain['categories'].first['name'].replace('Changed')

    expect(model['categories'].first['name']).to eq('Customers')
    expect(plain['phone']).to be_nil
  end

  it 'does not expose mutable internal strings or collections' do
    expect(model['id']).to be_frozen
    expect(model['categories']).to be_frozen
    expect { model['id'].replace('changed') }.to raise_error(FrozenError)
  end

  it 'supports standard JSON and Rails-compatible serialization' do
    parsed = JSON.parse(JSON.generate(model))

    expect(parsed.dig('categories', 0, 'id')).to eq('category_123')
    expect(model.as_json).to eq(model.to_h)
  end

  it 'serializes list envelopes and pagination metadata' do
    plain = model.to_h

    expect(plain['categories']).to be_an(Array)
    expect(plain['pagination']).to eq('has_more' => false, 'total' => 1)
  end
end
