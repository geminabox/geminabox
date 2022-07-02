require_relative '../test_helper'
require 'minitest/unit'
require 'rack/test'

class IsApiRequestTest < Minitest::Test
  include Rack::Test::Methods

  def setup
    clean_data_dir

    silence_stream($stdout) do
      Gem::Indexer.new(Geminabox.data).generate_index
    end
  end

  def app
    Geminabox::Server
  end

  test "test upload via web interface" do
    filename = GemFactory.gem_file(:example)
    header "Accept", "text/html"
    silence_stream($stdout) do
      post '/upload', { file: Rack::Test::UploadedFile.new(filename, 'application/octet-stream', true) }
    end

    follow_redirect!

    assert last_response.ok?
    assert_match(/<h1>Gem in a Box<\/h1>/, last_response.body)
  end

  test "test upload via api" do
    filename = GemFactory.gem_file(:example)
    header "Accept", "text/plain"
    silence_stream($stdout) do
      post '/upload', { file: Rack::Test::UploadedFile.new(filename, 'application/octet-stream', true) }
    end

    assert last_response.ok?
    assert_match(/Gem .* received and indexed\./, last_response.body)
  end
end
