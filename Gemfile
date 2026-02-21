source "https://rubygems.org"

gemspec

group :development do
  gem 'byebug'
end
group :test do
  if RUBY_VERSION >= '4.0'
    gem 'minitest'
    # minitest-mock was extracted from minitest in 5.26;
    # minitest-mock 5.27+ requires Ruby >= 3.1
    gem 'minitest-mock'
  else
    # minitest < 5.26 still bundles minitest/mock
    gem 'minitest', '< 5.26'
  end
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

  gem 'logger'
  gem 'webmock'

  # Used only in test/requests/atom_feed_test.rb
  gem "rss", require: false

  gem "simplecov"
end
