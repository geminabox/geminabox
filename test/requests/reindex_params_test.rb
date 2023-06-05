require_relative '../test_helper'
require 'rack/test'
require 'rss/atom'

class ReindexParamsTest < Minitest::Test
  include Rack::Test::Methods

  def setup
    clean_data_dir
  end

  def app
    Geminabox::Server
  end

  test "accessing the reindex url requires the force_rebuild parameter to be true or false" do
    get "/reindex?force_rebuild=foo"
    assert last_response.bad_request?
  end
end
