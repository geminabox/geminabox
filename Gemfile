source "https://rubygems.org"

gemspec

# Required for Ruby 3.3+ (Gem::Indexer extracted from RubyGems into a bundled gem).
# Bundler blocks bundled gems unless explicitly listed. Can't go in gemspec —
# the gem requires Ruby >= 3.0 and breaks Bundler resolution on 2.x.
gem 'rubygems-generate_index' if RUBY_VERSION >= '3.3'
group :development do
  gem 'byebug'
end
group :test do
  gem 'minitest', '< 7'
  gem 'minitest-reporters'
  gem 'rack-test'
  gem 'rake'

  gem 'capybara-mechanize'
  # Pin capybara to 3.36.x or earlier as 3.37.x does not work with Ruby 2.7/3.0/3.1
  # see https://github.com/teamcapybara/capybara/pull/2546
  gem 'capybara', '< 3.37.0'
  # Required for Ruby 3.4+ - nkf was extracted from stdlib
  # mechanize (used by capybara-mechanize) depends on nkf for character encoding
  gem 'nkf'

  gem 'webmock'

  # Used only in test/requests/atom_feed_test.rb
  gem "rss", require: false

  gem "simplecov"
end
