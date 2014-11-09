require 'test_helper'
require 'minitest/unit'
require 'system/geminabox_system_test'

class IsApiRequestTest < Minitest::Test
  include GeminaboxSystemTest

  def setup
    delete("/api/v1/gems")
    @example_file = Rack::Test::UploadedFile.new(GemFactory.gem_file(:example), 'application/octet-stream', true)
  end

  test "test upload via web interface" do


    post '/upload', :headers => {'Accept' => 'text/html'}, :body => { file: @example_file }

    assert_equal 303,                      last_response.code                , "Expected 303 because a new resource has been created"
    assert_equal "#{Settings.base_earl}/", last_response.headers['Location'] , "Expected to be redirected to root"
  end

  test "test upload via api" do
    post '/upload', :headers => {'Accept' => 'application/json'}, :body => { file: @example_file}

    assert last_response.ok?
    
    assert_match(/Gem .* received and indexed\./, last_response.body)
  end
end
