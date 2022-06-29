# Contributing to geminabox

## Bug reports

- Check if a bug you run into is already filed in https://github.com/geminabox/geminabox/issues.
   - Please add your comments to the issue if you find.
- Check if a bug you run into is already fixed in [the latest release](https://github.com/geminabox/geminabox/releases) or [the gem available at RubyGems.org](https://rubygems.org/gems/geminabox).
   - The latest release as of 2022-06 is 2.1.0.
- File a new issue at https://github.com/geminabox/geminabox/issues/new

## Code contributions

- Fork the repository.
- Add tests if you change behavior or add a feature.
- Write clear and precise commit message.
- Push your change to the forked repository.
- Create a PR with your change in the repository.
- Write a good title for the PR.
  - The title will be used for changelog.
- Include the reason and relevant issue link(s) if exists.
- Changelog in CHANGELOG.md is now replaced by PR title.
- Make sure if Checks in your PR are green.

### Setup development environment

1. Fork the repository: e.g.:
   - `git clone https://github.com/geminabox/geminabox.git` or
   - `gh repo clone geminabox/geminabox`
   - open a Codespace workspace at https://github.dev/geminabox/geminabox
2. Prepare Ruby 3.1, RubyGems 3.3, and Bundler 2.3.
3. Retrieve all dependencies with `bundle install`.
4. Change code whatever you want.
5. Test with `bundle exec rake test`.

## First contribution?

If you want to help us something, see the issue list for first-time contributors:
https://github.com/geminabox/geminabox/contribute
