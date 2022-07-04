require_relative '../../test_helper'
require 'httpclient'

class ReindexApiTest < Geminabox::TestCase
  test "reindexing with forced rebuild" do
    response = reindex(force_rebuild: true)
    assert_equal 302, response.code
  end

  test "reindexing with incremental rebuild" do
    response = reindex(force_rebuild: false)
    assert_equal 302, response.code
  end

  protected

  def reindex(force_rebuild:)
    HTTPClient.new.get(url_for("reindex"), { 'force_rebuild' => force_rebuild.to_s })
  end

end
