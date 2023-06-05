require_relative '../test_helper'
require 'rack/test'
require 'rss/atom'

class GemUploadTest < Minitest::Test
  include Rack::Test::Methods

  def setup
    clean_data_dir
  end

  def app
    Geminabox::Server
  end

  test "can access the upload page" do
    get "/upload"
    assert last_response.ok?
  end

  test "uploading a gem via web ui requires a file parameter" do
    header "Accept", "text/html"
    post "/upload"
    assert last_response.bad_request?
  end

  test "accessing the upload page is forbidden if uploads are disabled" do
    Geminabox.stub(:allow_upload, false) do
      header "Accept", "text/html"
      get "/upload"
      assert last_response.forbidden?

      header "Accept", "text/html"
      post "/upload"
      assert last_response.forbidden?
    end
  end

  test "uploading via gemcutter api is forbidden if uploads are disabled" do
    Geminabox.stub(:allow_upload, false) do
      post "/api/v1/gems"
      assert last_response.forbidden?
    end
  end
end
