source "https://rubygems.org"

gemspec
group :development do
  gem 'byebug'
  gem 'rubocop', '~> 1.31.0'
  gem 'rubocop-minitest', '~> 0.20.1'
  gem 'rubocop-rake', '~> 0.6.0'
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

  gem 'webmock'

  # Used only in test/requests/atom_feed_test.rb
  gem "rss", require: false

  gem "simplecov"
end
