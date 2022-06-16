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
  gem 'capybara', '< 3.38.0'

  # Pin multipart-post 2.1.x on Ruby 2.2 or earlier.
  # You can remove this block when multipart-post 2.2.0 is yanked
  # from RubyGems.org.
  # https://github.com/socketry/multipart-post/issues/92#issuecomment-1147101121
  if Gem::Version.create(RUBY_VERSION) < Gem::Version.create("2.3.0")
    gem 'multipart-post', '~> 2.1.1'
  end

  gem 'webmock'
end
