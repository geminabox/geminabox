source "https://rubygems.org"

gemspec
group :development do
  gem 'byebug'
end
group :test do
  gem 'rake'
  gem 'rack-test'
  gem 'minitest'

  gem 'capybara-mechanize'
  # Pin capybara to 3.36.x or earlier as 3.37.x does not work with Ruby 2.7/3.0/3.1
  # see https://github.com/teamcapybara/capybara/pull/2546
  gem 'capybara', '< 3.37.0'

  gem 'webmock'
end
