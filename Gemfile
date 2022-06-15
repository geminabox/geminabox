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

  # Pin multipart-post 2.1.x on Ruby 2.2 or earlier.
  # You can remove this block when multipart-post 2.2.0 is yanked
  # from RubyGems.org.
  # https://github.com/socketry/multipart-post/issues/92#issuecomment-1147101121
  if Gem::Version.create(RUBY_VERSION) < Gem::Version.create("2.3.0")
    gem 'multipart-post', '~> 2.1.1'
  end

  gem 'webmock'
end
