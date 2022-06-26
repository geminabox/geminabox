require_relative '../../test_helper'
require 'httpclient'

class VersionsApiTest < Geminabox::TestCase
  test "fetch versions" do
    assert_can_push(:gem1, :version => "1.0.0")
    assert_can_push(:gem1, :version => "2.0.0")
    assert_can_push(:gem2, :deps => [[:gem3, '>= 1']], :version => "3.0.0")

    response = HTTPClient.new.get_content(url_for("versions"))
    assert_match(/gem1 1\.0\.0,2\.0\.0/, response)
    assert_match(/gem2 3\.0\.0/, response)
    assert_match(/created_at: \d{4}-/, response)
  end
end
