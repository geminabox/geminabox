# Contributing to geminabox

## Bug reports

- Check if a bug you run into is already filed in https://github.com/geminabox/geminabox/issues.
   - Please add your comments to the issue if you find.
- Check if a bug you run into is already fixed in [the latest release](https://github.com/geminabox/geminabox/releases) or [the gem available at RubyGems.org](https://rubygems.org/gems/geminabox).
- File a new issue at https://github.com/geminabox/geminabox/issues/new

## Code contributions

- Fork the repository.
- Add tests if you change behavior or add a feature.
- Write clear and precise commit message.
- Push your change to the forked repository.
- Create a PR with your change in the repository.
- Write a good title for the PR.
- Include the reason and relevant issue link(s) if exists.
- Add an entry under `## [Unreleased]` in CHANGELOG.md for user-visible changes.
- Make sure if Checks in your PR are green.

### Setup development environment

1. Fork and clone the repository: e.g.:
   - `gh repo fork geminabox/geminabox --clone` or
   - fork on GitHub, then `git clone` your fork
2. Prepare Ruby 3.0 or newer (CI tests 3.0 through 4.0) and RubyGems 3.2.3 or newer.
3. Retrieve all dependencies with `bundle install`.
4. Change code whatever you want.
5. Run the same checks as CI:
   - `bundle exec rake test`
   - `bundle exec rubocop`
   - `bundle exec rake test:conformance` if you touch the compact index
   - `npx prettier@3.9.5 --trailing-comma none --check public/**/*.js public/**/*.css` if you touch JS or CSS

## First contribution?

If you want to help us something, see the issue list for first-time contributors:
https://github.com/geminabox/geminabox/contribute
