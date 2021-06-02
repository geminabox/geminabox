require_relative '../../test_helper'
require 'httpclient'

class NamesApiTest < Geminabox::TestCase
  test "fetch names" do
    assert_can_push(:names_x, :version => "1.0.0")
    assert_can_push(:names_a, :version => "1.0.0")
    assert_can_push(:names_a, :version => "2.0.0")
    assert_can_push(:names_b, :deps => [[:names_c, '>= 1']], :version => "3.0.0")

    response = HTTPClient.new.get_content(url_for("names"))
    assert("---\nnames_a\nnames_b\nnames_x", response)
  end
end
