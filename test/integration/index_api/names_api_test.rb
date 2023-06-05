require_relative '../../test_helper'
require 'httpclient'

class NamesApiTest < Geminabox::TestCase
  test "fetch names" do
    assert_can_push(:names_x, :version => "1.0.0")
    assert_can_push(:names_a, :version => "1.0.0")
    assert_can_push(:names_a, :version => "2.0.0")
    assert_can_push(:names_b, :deps => [[:names_c, '>= 1']], :version => "3.0.0")

    response = HTTPClient.new.get_content(url_for("names"))
    lines = response.split("\n")
    assert_equal ["---", "names_a", "names_b", "names_x"], lines
  end

  test "fetch names supports etags" do
    assert_can_push(:names_x, :version => "1.0.0")
    response1 = HTTPClient.new.get(url_for("names"))
    etag = response1.headers["Etag"]
    response2 = HTTPClient.new.get(url_for("names"), nil, { "If-None-Match" => etag })
    assert_equal 304, response2.code
  end
end
