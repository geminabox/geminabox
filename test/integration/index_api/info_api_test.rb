require_relative '../../test_helper'
require 'httpclient'

class InfoApiTest < Geminabox::TestCase
  test "get info with deps" do
    assert_can_fetch(:gem_with_dependencies, :deps => [[:dependency, '>= 1']], :version => "3.0.0")
    response = fetch_info("gem_with_dependencies")
    lines = response.split("\n")
    assert_match(/3\.0\.0 dependency:>= 1|checksum:\S{64}/, lines[1])
  end

  test "get info multiple versions" do
    assert_can_fetch(:test_multiple, :version => "1.0.0")
    assert_can_fetch(:test_multiple, :version => "2.0.0")

    response = fetch_info("test_multiple")
    lines = response.split("\n")
    assert_match(/\A1\.0\.0 |checksum:\S{64}/, lines[1])
    assert_match(/\A2\.0\.0 |checksum:\S{64}/, lines[2])
  end

  test "get info with requirements" do
    assert_can_fetch(:requirements, :deps => [[:dependency2, '>= 1']], :version => "3.0.0", :required_ruby_version => ">=3.0.0", :required_rubygems_version => ">1.3.1")
    response = fetch_info("requirements")
    lines = response.split("\n")
    assert_equal("---", lines[0])
    assert_match(/,ruby:>= 3\.0\.0,rubygems:> 1\.3\.1/, lines[1])
  end

  test "getting info supports etags" do
    assert_can_push(:example, :version => "1.0.0")
    info_url = url_for("info/example")
    response1 = HTTPClient.new.get(info_url)
    etag = response1.headers["Etag"]
    response2 = HTTPClient.new.get(info_url, nil, { "If-None-Match" => etag })
    assert_equal 304, response2.code
  end

  test "getting info for unknoen gem returns 404" do
    info_url = url_for("info/foobar")
    response = HTTPClient.new.get(info_url)
    assert_equal 404, response.code
  end

  protected

  def fetch_info(name)
    HTTPClient.new.get_content(url_for("info/#{name}"))
  end
end
