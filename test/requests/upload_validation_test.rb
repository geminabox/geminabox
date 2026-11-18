require_relative '../test_helper'
require 'rack/test'

# A spec that RubyGems stores without complaint can still fail to load back
# from the Marshal index or corrupt the line-oriented compact index, so these
# uploads must be refused before anything is written to disk.
class UploadValidationTest < Minitest::Test
  include Rack::Test::Methods

  attr_reader :app

  def setup
    clean_data_dir
    # The class-level dependency cache outlives clean_data_dir's rm_rf.
    Geminabox::Server.dependency_cache.flush
    inject_gems { |builder| builder.gem 'healthy', version: '1.0.0' }
    @app = Geminabox::Server.new!
  end

  test 'a malformed version is refused and the index keeps working' do
    push(crafted_gem do |s|
      bad = Gem::Version.allocate
      bad.instance_variable_set(:@version, '1.0 x 2')
      s.instance_variable_set(:@version, bad)
    end)

    assert_equal 400, last_response.status
    assert_empty Dir.glob(File.join(Geminabox.data, 'gems', 'victim-*'))

    get '/', {}, 'HTTP_ACCEPT' => 'text/html'
    assert_equal 200, last_response.status
    get '/api/v1/dependencies', gems: 'healthy'
    assert_equal 200, last_response.status
  end

  test 'a dependency name carrying compact-index separators is refused' do
    push(crafted_gem do |s|
      s.add_dependency 'rack'
      s.dependencies.first.instance_variable_set(:@name, "rack\n2.0.0 |checksum:x")
    end)

    assert_equal 400, last_response.status
    get '/info/victim'
    assert_equal 404, last_response.status
  end

  test 'an unindexable platform is refused' do
    push(crafted_gem { |s| s.platform = 'i686-linux' })

    assert_equal 400, last_response.status
    assert_empty Dir.glob(File.join(Geminabox.data, 'gems', 'victim-*'))
  end

  private

  def push(path)
    post '/api/v1/gems', File.binread(path), 'CONTENT_TYPE' => 'application/octet-stream'
  end

  # A client can write any spec into the archive; skip_validation and
  # instance_variable_set stand in for a hand-crafted metadata.gz.
  def crafted_gem
    spec = Gem::Specification.new do |s|
      s.name = 'victim'
      s.version = '1.0.0'
      s.summary = 'x'
      s.authors = ['x']
      s.files = []
    end
    yield spec
    path = File.join(TEST_DATA_DIR, 'crafted.gem')
    silence { Gem::Package.build(spec, true, false, path) }
    path
  end
end
