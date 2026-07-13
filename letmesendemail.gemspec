# frozen_string_literal: true

require_relative 'lib/letmesendemail/version'

Gem::Specification.new do |spec|
  spec.name = 'letmesendemail'
  spec.version = LetMeSendEmail::VERSION
  spec.authors = ['letmesendemail']
  spec.summary = 'letmesend.email Ruby SDK.'
  spec.description = 'Official Ruby SDK for the letmesend.email API.'
  spec.homepage = 'https://letmesend.email/'
  spec.license = 'MIT'
  spec.required_ruby_version = '>= 3.1'

  spec.files = Dir['lib/**/*.rb', 'docs/**/*.md', 'examples/**/*.rb'] +
               %w[README.md CHANGELOG.md LICENSE.md]
  spec.require_paths = ['lib']

  spec.add_dependency 'base64', '~> 0.2'

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = 'https://github.com/letmesendemail/letmesendemail-ruby'
  spec.metadata['changelog_uri'] =
    'https://github.com/letmesendemail/letmesendemail-ruby/blob/master/CHANGELOG.md'
  spec.metadata['allowed_push_host'] = 'https://rubygems.org'
  spec.metadata['rubygems_mfa_required'] = 'true'
end
