require_relative '../test_helper'
require 'rack/test'

# Rack::Protection::PathTraversal normally strips ".." from PATH_INFO before
# routing. These tests call the apps via `new!`, which skips all middleware,
# so the handlers themselves must keep file access inside Geminabox.data.
class PathContainmentTest < Minitest::Test
  include Rack::Test::Methods

  attr_reader :app

  def setup
    clean_data_dir
    # Nest the data dir so the outside file shares its name as a prefix,
    # which a containment check without a trailing separator would accept.
    Geminabox.data = File.join(TEST_DATA_DIR, 'data')
    FileUtils.mkdir_p(File.join(Geminabox.data, 'gems'))
    @outside = File.join(TEST_DATA_DIR, 'data-outside.gem')
    File.write(@outside, 'secret')
    @traversal = '/gems/../../data-outside.gem'
  end

  def teardown
    Geminabox.data = TEST_DATA_DIR
  end

  test 'Hostess refuses to serve a file outside the data dir' do
    @app = Geminabox::Hostess.new!
    get @traversal

    assert_equal 404, last_response.status
    refute_includes last_response.body, 'secret'
  end

  test 'DELETE /gems refuses to delete a file outside the data dir' do
    @app = Geminabox::Server.new!
    delete @traversal

    assert_equal 404, last_response.status
    assert File.exist?(@outside), 'file outside the data dir must survive'
  end

  test 'POST /api/v1/gems refuses a gem whose name escapes the gems dir' do
    evil = build_gem_named('../../evil')
    @app = Geminabox::Server.new!
    post '/api/v1/gems', File.binread(evil), 'CONTENT_TYPE' => 'application/octet-stream'

    assert_equal 400, last_response.status
    refute File.exist?(File.join(TEST_DATA_DIR, 'evil-1.0.0.gem')), 'upload must not land outside the gems dir'
  end

  test 'DELETE /gems still deletes a gem inside the data dir' do
    inject_gems { |builder| builder.gem 'jem', version: '1.0.0' }
    @app = Geminabox::Server.new!
    delete '/gems/jem-1.0.0.gem'

    assert_equal 302, last_response.status
    refute File.exist?(File.join(Geminabox.data, 'gems', 'jem-1.0.0.gem'))
  end

  private

  # A client can craft the archive directly; skip_validation stands in for that.
  def build_gem_named(name)
    spec = Gem::Specification.new do |s|
      s.name = name
      s.version = '1.0.0'
      s.summary = 'x'
      s.authors = ['x']
    end
    path = File.join(TEST_DATA_DIR, 'crafted.gem')
    silence { Gem::Package.build(spec, true, false, path) }
    path
  end
end
