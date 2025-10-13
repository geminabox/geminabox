source "https://rubygems.org"

gemspec
group :development do
  gem 'byebug'
end
group :test do
  gem 'minitest'
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
  # Required for Ruby 3.5+ - ostruct will be extracted from stdlib
  # rack (used by sinatra and test framework) depends on ostruct
  gem 'ostruct'

  gem 'webmock'

  # Used only in test/requests/atom_feed_test.rb
  gem "rss", require: false

  gem "simplecov"
end
