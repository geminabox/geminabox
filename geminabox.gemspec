require File.expand_path('../lib/geminabox/version', __FILE__)

Gem::Specification.new do |s|
  s.name              = 'geminabox'
  s.version           = GeminaboxVersion
  s.summary           = 'Really simple rubygem hosting'
  s.description       = 'A sinatra based gem hosting app, with client side gem push style functionality.'
  s.author            = 'Rally Software Development Corp'
  s.email             = 'integrations@rallydev.com'
  s.homepage          = 'http://www.rallydev.com/'

  s.has_rdoc          = true
  s.extra_rdoc_files  = %w[README.markdown]
  s.rdoc_options      = %w[--main README.markdown]

  s.files             = %w[README.markdown] + Dir['{lib,public,views}/**/*']
  s.require_paths     = ['lib']

  s.add_dependency('sinatra')
  s.add_dependency('builder')
  s.add_dependency('httpclient', [">= 2.2.7"])
  s.add_development_dependency('rake')
  s.add_development_dependency('rack-test')
  s.add_development_dependency('minitest')
  s.add_development_dependency('capybara')
  s.add_development_dependency('capybara-mechanize')
  s.add_development_dependency('pry')
end
