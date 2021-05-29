source "https://rubygems.org"

gemspec
group :development do
  gem 'byebug'
end
group :test do
  gem 'rake'
  gem 'rack-test'
  gem 'minitest'

  if Gem::Version.create(RUBY_VERSION) >= Gem::Version.create("3.0.0")
    # FIXME: test is failed on Ruby 3.0+
    # c.f. https://github.com/jeroenvandijk/capybara-mechanize/issues/68
    gem 'capybara-mechanize', github: 'tomstuart/capybara-mechanize', ref: '64073e9'
  else
    gem 'capybara-mechanize', '1.10.0'
  end

  gem 'webmock'
end
