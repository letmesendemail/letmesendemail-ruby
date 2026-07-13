# Publishing `letmesendemail`

This standalone repository publishes the `letmesendemail` gem to [RubyGems.org](https://rubygems.org/gems/letmesendemail).

## Maintainer prerequisites

- A RubyGems.org account with multi-factor authentication enabled.
- Ownership of the `letmesendemail` gem name for later releases.
- Ruby 3.1 or newer and Bundler.
- Push access to the standalone Git repository.
- A clean `master` branch with CI passing.

Before the first release, create the public repository at
`https://github.com/letmesendemail/letmesendemail-ruby` and verify that the
gemspec's source and changelog links resolve. Do not publish while those links
return an error.

For manual publishing, authenticate interactively with `gem signin`. In approved CI, store a scoped RubyGems API key in the secret `RUBYGEMS_API_KEY` and expose it only to the publish step as `GEM_HOST_API_KEY`. Never commit credentials or place them in shell history.

## Version and release notes

The version source of truth is `LetMeSendEmail::VERSION` in `lib/letmesendemail/version.rb`; the gemspec reads that constant. Before releasing:

1. Set the intended semantic version in `lib/letmesendemail/version.rb`.
2. Move relevant entries from `Unreleased` in `CHANGELOG.md` to a heading for that version and the actual release date.
3. Confirm README and `docs/docs.md` match the code.
4. Run the complete validation gate below.

## Pre-publish validation

Run from the standalone repository root:

```bash
gem install bundler --version 2.6.9
bundle _2.6.9_ install
bundle _2.6.9_ exec rubocop --parallel
bundle _2.6.9_ exec rspec
ruby -Ilib -e 'require "letmesendemail"; abort unless LetMeSendEmail::VERSION'
find examples -name "*.rb" -print0 | xargs -0 -n1 ruby -c
gem build letmesendemail.gemspec
gem specification letmesendemail-*.gem --yaml
gem unpack letmesendemail-*.gem --target pkg/inspection
find pkg/inspection -type f -print | sort
```

Inspect the unpacked gem and confirm it contains the license, README, changelog, user manual, examples, and all library files, with no credentials, environment files, editor files, tests, or build output.

Verify the package in an isolated directory before publishing:

```bash
mkdir -p pkg/verify
gem install --install-dir pkg/verify --local letmesendemail-*.gem
RUBYLIB="pkg/verify/gems/letmesendemail-$(ruby -Ilib -rletmesendemail -e 'print LetMeSendEmail::VERSION')/lib" \
  ruby -e 'require "letmesendemail"; puts LetMeSendEmail::VERSION'
```

Remove local `pkg/` output before committing.

## Commit, tag, and publish

Replace `0.1.0` with the version being released:

```bash
git status --short
git add -A
git commit -m "Release v0.1.0"
git tag -a v0.1.0 -m "Release 0.1.0"
git push origin master
git push origin v0.1.0
gem push letmesendemail-0.1.0.gem
```

If CI performs trusted publishing, push the reviewed tag and let the protected release workflow publish exactly that tag. Do not also run `gem push` manually.

## Verify the public release

Wait for RubyGems.org to index the version, then use a clean temporary install location:

```bash
gem info letmesendemail --remote --version 0.1.0
gem install letmesendemail --version 0.1.0 --install-dir pkg/public-verify
RUBYLIB="pkg/public-verify/gems/letmesendemail-0.1.0/lib" \
  ruby -e 'require "letmesendemail"; abort unless LetMeSendEmail::VERSION == "0.1.0"'
```

Also verify the gem page shows the expected metadata, license, required Ruby version, and documentation files.

## Recovery

RubyGems releases are immutable. If a release is broken:

1. Stop deployment and document the issue.
2. Fix it and publish a new patch version whenever possible.
3. Yank only when necessary:

```bash
gem yank letmesendemail -v 0.1.0
```

Yanking prevents new resolution but does not remove copies already downloaded. Never reuse a released version number or move an existing Git tag. Publish a corrected version and communicate the replacement in the changelog and release notes.
