require File.expand_path('../lib/geminabox/version', __FILE__)

Gem::Specification.new do |s|
  s.name              = 'geminabox'
  s.version           = Geminabox::VERSION
  s.summary           = 'Really simple private RubyGems hosting'
  s.description       = 'A private gem hosting and/or caching app, with client side gem push style functionality. Web UI is provided.'
  s.authors           = ['Tom Lea', 'Jack Foy', 'Rob Nichols', 'Naotoshi Seo', "Takuya Noguchi"]
  s.email             = ['contrib@tomlea.co.uk', 'jack@foys.net', 'rob@undervale.co.uk', 'sonots@gmail.com', "takninnovationresearch@gmail.com"]
  s.homepage          = "https://github.com/geminabox/geminabox"

  s.metadata["homepage_uri"]    = s.homepage
  s.metadata["source_code_uri"] = "https://github.com/geminabox/geminabox"
  s.metadata["changelog_uri"]   = "https://github.com/geminabox/geminabox/releases"

  s.required_ruby_version     = ">= 2.3.0"
  s.required_rubygems_version = ">= 2.5.0"

  s.extra_rdoc_files  = %w[README.md]
  s.rdoc_options      = %w[--main README.md]

  s.license           = 'MIT-LICENSE'
  s.files             = %w[MIT-LICENSE README.md] + Dir['{lib,public,views}/**/*'] + %w[bin/geminabox]
  s.executables       = s.files.grep(%r{^bin/}) { |f| File.basename(f) }
  s.require_paths     = ['lib']

  s.add_dependency('sinatra', "~> 2.0")
  s.add_dependency('builder')
  s.add_dependency('httpclient', [">= 2.2.7"])
  s.add_dependency('nesty')
  s.add_dependency('faraday', "> 1.0", "< 3.0")
  s.add_dependency('reentrant_flock')
  s.add_dependency('parallel')
  s.add_dependency('ruby-progressbar')
end
