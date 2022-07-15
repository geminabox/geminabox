require_relative '../test_helper'
require 'rack/test'

class DependencyApiWithProxyEnabledTest < Minitest::Test
  include Rack::Test::Methods

  def setup
    clean_data_dir
    Geminabox.rubygems_proxy = true
    inject_gems do |builder|
      builder.gem(:foo)
    end
    Geminabox::Indexer.new.reindex(:force_rebuild)
  end

  def teardown
    Geminabox.rubygems_proxy = false
  end

  def app
    Geminabox::Server
  end

  test "can retrieve remote dependencies" do
    stub_request(:get, 'https://bundler.rubygems.org/api/v1/dependencies?gems=example')
      .to_return(status: 200, body: Marshal.dump(example_dependencies), headers: { 'Content-Type' => 'application/octet-stream' })

    fetch_deps(:example)
    assert last_response.ok?, "unexpected response --> #{last_response.inspect}"

    assert_equal example_dependencies, Marshal.load(last_response.body)
  end

  test "can retrieve local dependencies" do
    stub_request(:get, 'https://bundler.rubygems.org/api/v1/dependencies?gems=foo')
      .to_return(status: 200, body: Marshal.dump([]), headers: { 'Content-Type' => 'application/octet-stream' })

    fetch_deps(:foo)
    assert last_response.ok?, "unexpected response --> #{last_response.inspect}"

    assert_equal foo_dependencies, Marshal.load(last_response.body)
  end

  private

  def fetch_deps(*gems)
    header "Accept", "application/octet-stream"
    get("/api/v1/dependencies?gems=#{gems.join(',')}")
  end

  def foo_dependencies
    [
      { :name => "foo", :number => "1.0.0", :platform => "ruby", :dependencies => [] }
    ]
  end

  def example_dependencies
    [
      { name: 'example', number: '0.0.1', platform: 'ruby', dependencies: [] },
      { name: 'example', number: '0.0.2', platform: 'ruby', dependencies: [] }
    ]
  end

end
