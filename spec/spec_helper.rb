ENV['RACK_ENV'] = "test"
require 'bundler/setup'
Bundler.definition.specs_for([:default, :development, :test]).map do |s|
  next if s.name == "rspec-rails"
  require s.name.sub('-', '/')
end

require File.dirname(__FILE__) + '/../lib/geminabox'

RSpec.configure do |config|
  config.include Rack::Test::Methods
  config.include RspecTagMatchers
  config.mock_with :mocha
  def app
    Geminabox
  end
  def env
    last_request.instance_variable_get(:@env)
  end
  def session
    last_request.instance_variable_get(:@env)['rack.session']
  end
  def flash
    last_request.instance_variable_get(:@env)['x-rack.flash']
  end
end
