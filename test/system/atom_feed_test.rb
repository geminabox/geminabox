require 'test_helper'
require 'minitest/unit'

module GeminaboxSystemTest
  attr_accessor :last_response 

  def get(relative_uri)
    @last_response = internet.get "http://localhost:9292#{relative_uri}"
  end

  private

  def internet
    Geminabox::HttpClientAdapter.new
  end
end

class AtomFeedTest < Minitest::Test
  include GeminaboxSystemTest

  test "atom feed returns when no gems are defined" do
    get "/atom.xml"
    
    assert last_response.ok?
    
    refute_match %r{<entry>}, last_response.body
  end
end
