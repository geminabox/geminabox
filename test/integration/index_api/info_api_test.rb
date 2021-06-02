require_relative '../../test_helper'
require 'httpclient'

class InfoApiTest < Geminabox::TestCase
  test "get info with deps" do
    assert_can_fetch(:gem_with_dependencies, :deps => [[:dependency, '>= 1']], :version => "3.0.0")
    response = fetch_info("gem_with_dependencies")
    assert_match(/3\.0\.0 dependency:>= 1|checksum:\S{64}/, response)
  end

  test "get info multiple versions" do
    assert_can_fetch(:test_multiple, :version => "1.0.0")
    assert_can_fetch(:test_multiple, :version => "2.0.0")

    response = fetch_info("test_multiple")
    assert_match(/1\.0\.0 |checksum:\S{64}/, response)
    assert_match(/2\.0\.0 |checksum:\S{64}/, response)
  end

  test "get info with requirements" do
    assert_can_fetch(:requirements, :deps => [[:dependency2, '>= 1']], :version => "3.0.0", :required_ruby_version => ">=3.0.0", :required_rubygems_version => ">1.3.1")
    response = fetch_info("requirements")
    assert_match(/,ruby:>= 3\.0\.0,rubygems:> 1\.3\.1/, response)
  end

  protected

  def fetch_info(name)
    HTTPClient.new.get_content(url_for("info/#{name}"))
  end
end
