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
    gem 'capybara-mechanize'
    gem 'capybara', '~> 3.36.0' # Pin to 3.36.x
  else
    gem 'capybara-mechanize', '1.10.0'
  end

  gem 'webmock'
end
