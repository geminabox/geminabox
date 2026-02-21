source "https://rubygems.org"

gemspec

group :development do
  gem 'byebug'
end
group :test do
  gem 'minitest', '< 6'
  gem 'minitest-reporters'
  gem 'rack-test'
  gem 'rackup'
  gem 'rake'

  gem 'capybara'
  gem 'capybara-mechanize'
  # Required for Ruby 3.4+ - nkf was extracted from stdlib
  # mechanize (used by capybara-mechanize) depends on nkf for character encoding
  gem 'nkf'
  # Required for Ruby 4.0+ - ostruct will be extracted from stdlib
  # rack and sinatra depend on ostruct for option handling
  gem 'ostruct'

  gem 'webmock'

  # Used only in test/requests/atom_feed_test.rb
  gem "rss", require: false

  gem "simplecov"
end
