# frozen_string_literal: true

RSpec.describe 'Error classes' do
  specify 'AuthenticationError' do
    err = LetMeSendEmail::AuthenticationError.new('Unauthorized', status_code: 401, api_code: 'unauth')
    expect(err).to be_a(LetMeSendEmail::Error)
    expect(err.status_code).to eq(401)
    expect(err.api_code).to eq('unauth')
  end

  specify 'ValidationError with field errors' do
    err = LetMeSendEmail::ValidationError.new('Invalid', status_code: 422,
                                                         validation_errors: { 'email' => ['Required'] })
    expect(err.validation_errors).to have_key('email')
    expect(err.validation_errors['email']).to include('Required')
  end

  specify 'RateLimitError' do
    err = LetMeSendEmail::RateLimitError.new('Limited', status_code: 429,
                                                        retry_after: 120, limit: 100,
                                                        remaining: 50, reset_at: '2026-01-01')
    expect(err.retry_after).to eq(120)
    expect(err.limit).to eq(100)
  end

  specify 'NotFoundError' do
    expect(LetMeSendEmail::NotFoundError.new('Not found')).to be_a(LetMeSendEmail::Error)
  end

  specify 'ApiError for server errors' do
    expect(LetMeSendEmail::ApiError.new('Server error')).to be_a(LetMeSendEmail::Error)
  end

  specify 'NetworkError' do
    expect(LetMeSendEmail::NetworkError.new('connection failed')).to be_a(LetMeSendEmail::Error)
  end

  specify 'TimeoutError' do
    expect(LetMeSendEmail::TimeoutError.new('timed out')).to be_a(LetMeSendEmail::Error)
  end
end
