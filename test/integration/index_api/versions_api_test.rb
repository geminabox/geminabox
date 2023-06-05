require_relative '../../test_helper'
require 'httpclient'

class VersionsApiTest < Geminabox::TestCase
  test "fetch versions" do
    assert_can_push(:gem1, :version => "1.0.0")
    assert_can_push(:gem1, :version => "2.0.0")
    assert_can_push(:gem2, :deps => [[:gem3, '>= 1']], :version => "3.0.0")

    response = HTTPClient.new.get_content(url_for("versions"))
    lines = response.split("\n")
    assert_match(/\Acreated_at: \d{4}-/, lines[0])
    assert_equal("---", lines[1])
    assert_match(/\Agem1 1\.0\.0,2\.0\.0/, lines[2])
    assert_match(/\Agem2 3\.0\.0/, lines[3])
  end

  test "fetching versions etags" do
    assert_can_push(:example, :version => "1.0.0")
    versions_url = url_for("/versions")
    response1 = HTTPClient.new.get(versions_url)
    etag = response1.headers["Etag"]
    response2 = HTTPClient.new.get(versions_url, nil, { "If-None-Match" => etag })
    assert_equal 304, response2.code
  end
end
