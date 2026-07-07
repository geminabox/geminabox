require_relative '../test_helper'
require 'rack/test'

class YankTest < Minitest::Test
  include Rack::Test::Methods

  def app
    Geminabox::Server
  end

  def setup
    clean_data_dir
    Geminabox::Server.dependency_cache.flush
    inject_gems do |builder|
      builder.gem 'jem', version: '1.0.0'
      builder.gem 'jem', version: '1.0.0', platform: 'java'
    end
  end

  test 'yank without a platform removes only the ruby build' do
    delete '/api/v1/gems/yank', { 'gem_name' => 'jem', 'version' => '1.0.0' }

    assert_equal 200, last_response.status
    refute File.exist?(gem_path('jem-1.0.0.gem')), 'ruby build should be yanked'
    assert File.exist?(gem_path('jem-1.0.0-java.gem')),
           'the java build sharing the version must survive'
  end

  test 'yank with a platform removes only that platform' do
    delete '/api/v1/gems/yank',
           { 'gem_name' => 'jem', 'version' => '1.0.0', 'platform' => 'java' }

    assert_equal 200, last_response.status
    assert File.exist?(gem_path('jem-1.0.0.gem')), 'ruby build must survive'
    refute File.exist?(gem_path('jem-1.0.0-java.gem')), 'java build should be yanked'
  end

  test 'yank of an unknown version is a 404' do
    delete '/api/v1/gems/yank', { 'gem_name' => 'jem', 'version' => '9.9.9' }

    assert_equal 404, last_response.status
  end

  protected

  def gem_path(filename)
    File.join(Geminabox.data, 'gems', filename)
  end
end
