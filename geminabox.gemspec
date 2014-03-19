require File.expand_path('../lib/geminabox/version', __FILE__)

Gem::Specification.new do |s|
  s.name              = 'geminabox'
  s.version           = Geminabox::VERSION
  s.summary           = 'Really simple rubygem hosting'
  s.description       = 'A sinatra based gem hosting app, with client side gem push style functionality.'
  s.authors           = ['Tom Lea', 'Jack Foy', 'Rob Nichols']
  s.email             = ['contrib@tomlea.co.uk', 'jack@foys.net', 'rob@undervale.co.uk']
  s.homepage          = 'http://tomlea.co.uk/p/gem-in-a-box'

  s.has_rdoc          = true
  s.extra_rdoc_files  = %w[README.markdown]
  s.rdoc_options      = %w[--main README.markdown]

  s.license           = 'MIT-LICENSE'
  s.files             = %w[MIT-LICENSE README.markdown] + Dir['{lib,public,views}/**/*']
  s.require_paths     = ['lib']

  s.add_dependency('sinatra', [">= 1.2.7"])
  s.add_dependency('builder')
  s.add_dependency('httpclient', [">= 2.2.7"])
  s.add_dependency('nesty')
  s.add_dependency('faraday')
  s.add_development_dependency('rake')
  s.add_development_dependency('pry')
end
