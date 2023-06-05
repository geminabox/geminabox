require_relative '../test_helper'
require 'rack/test'
require 'rss/atom'

class GemDownloadTest < Minitest::Test
  include Rack::Test::Methods

  def setup
    clean_data_dir
  end

  def app
    Geminabox::Server
  end

  test "can download gems" do
    inject_gems do |builder|
      builder.gem "foo"
    end

    get "/gems/foo-1.0.0.gem"
    assert last_response.ok?
  end
end
