# frozen_string_literal: true

source 'https://rubygems.org'

gem 'base64'

gemspec

group :development, :test do
  # parallel 2.x requires Ruby 3.3+, while the SDK supports Ruby 3.1+.
  gem 'parallel', '< 2.0'
  gem 'rspec', '~> 3.12'
  gem 'rubocop', '~> 1.60', require: false
  gem 'rubocop-rspec', '~> 3.0', require: false
end
