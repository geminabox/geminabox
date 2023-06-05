require_relative '../test_helper'
require 'rack/test'

class XPoweredByTest < Minitest::Test
  include Rack::Test::Methods

  def app
    Geminabox::Server
  end

  %w[ / /gems ].each do |path|
    test "adds X-Powered-By when requesting '#{path}'" do
      get path
      assert_equal "geminabox #{Geminabox::VERSION}", last_response.headers['X-Powered-By']
    end
  end
end
