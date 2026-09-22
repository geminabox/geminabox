require_relative '../test_helper'
require 'minitest'
require 'rack/test'
require 'nokogiri'

# The UI steers clients to a Bundler scoped source, matching the README,
# rather than adding this server as a global RubyGems source.
class InstallInstructionsTest < Minitest::Test
  include Rack::Test::Methods

  def setup
    clean_data_dir
    inject_gems do |builder|
      builder.gem "foo", version: "1.2.3"
      builder.gem "bar", version: "2.0.0.pre"
    end
  end

  def app
    Geminabox::Server
  end

  def doc
    Nokogiri::HTML(last_response.body)
  end

  def row_commands(path, env = {})
    get path, {}, env
    doc.css(".version-row code").map { |code| code.text.strip }
  end

  test "the index never recommends adding a global gem source" do
    get "/"
    refute_match(/gem sources -a/, last_response.body)
  end

  test "the index shows a scoped source block for this server" do
    get "/"
    assert_includes doc.css(".intro").text, 'source "http://example.org/" do'
  end

  test "the index keeps credentials out of the source URL" do
    get "/"
    assert_includes doc.css(".intro").text,
                    "bundle config set --global example.org username:password"
  end

  test "version rows offer a pessimistic Gemfile line" do
    ["/", "/gems/foo"].each do |path|
      assert_includes row_commands(path), 'gem "foo", "~> 1.2.3"', "on #{path}"
    end
  end

  test "prerelease rows carry the prerelease version in the requirement" do
    assert_includes row_commands("/"), 'gem "bar", "~> 2.0.0.pre"'
  end

  test "the source block follows a sub-URI mount" do
    get "/", {}, "SCRIPT_NAME" => "/gems"
    assert_includes doc.css(".intro").text, 'source "http://example.org/gems/" do'
  end
end
