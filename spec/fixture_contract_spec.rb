# frozen_string_literal: true

require 'json'

RSpec.describe 'API fixture response contracts' do
  fixtures = %w[
    email-send
    domain-show
    contact-show
    contact-category-show
    email-topic-store
  ].freeze

  fixtures.each do |name|
    it "round-trips the #{name} fixture through the public model" do
      path = File.join(__dir__, 'fixtures', "#{name}.json")
      fixture = JSON.parse(File.read(path))
      model = LetMeSendEmail::Models.wrap(fixture)

      expect(model).to be_a(LetMeSendEmail::Models::Model)
      expect(model.to_h).to eq(fixture)
      expect(JSON.parse(JSON.generate(model))).to eq(fixture)
    end
  end
end
