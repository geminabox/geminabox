require_relative '../test_helper'
require 'minitest'
require 'rack/test'

class ContentTypeTest < Minitest::Test
  include Rack::Test::Methods

  def setup
    clean_data_dir
  end

  def app
    Geminabox::Server
  end

  test 'root page returns html content type' do
    get '/'
    assert last_response.ok?
    assert_equal 'text/html', last_response.media_type
  end

  test 'upload page returns html content type' do
    get '/upload'
    assert last_response.ok?
    assert_equal 'text/html', last_response.media_type
  end

  test 'atom feed returns atom content type' do
    get '/atom.xml'
    assert last_response.ok?
    assert_equal 'application/atom+xml', last_response.media_type
  end

  test 'dependencies endpoint returns binary content type' do
    get '/api/v1/dependencies'
    assert last_response.ok?
    assert_equal 'application/octet-stream', last_response.media_type
  end

  test 'dependencies json endpoint returns json content type' do
    get '/api/v1/dependencies.json'
    assert last_response.ok?
    assert_equal 'application/json', last_response.media_type
  end

  test 'quick spec endpoint returns binary content type' do
    inject_gems { |builder| builder.gem 'example' }
    get '/quick/Marshal.4.8/example-1.0.0.gemspec.rz'
    assert last_response.ok?
    assert_equal 'application/octet-stream', last_response.media_type
  end
end
