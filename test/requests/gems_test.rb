require 'test_helper'
require 'minitest/unit'
require 'rack/test'

class GemsTest < Minitest::Test
  include Rack::Test::Methods

  def setup
    clean_data_dir
  end

  def app
    Geminabox::Server
  end

  test "gem badge" do
    gem_name = "foo"
    gem_version = "0.1.2"

    inject_gems do |builder|
      builder.gem gem_name, version: gem_version
    end

    get "/gems/#{gem_name}.svg"

    assert last_response.ok?
    assert_match /#{gem_version}/, last_response.body
    assert_equal "image/svg+xml", last_response.content_type
  end
end
