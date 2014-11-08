require 'test_helper'
require 'minitest/unit'
require 'system/geminabox_system_test'

class AtomFeedTest < Minitest::Test
  include GeminaboxSystemTest
  
  def setup
    delete("/api/v1/gems")
  end

  test "atom feed returns when no gems are defined" do
    get "/atom.xml"
    
    assert last_response.ok?
    
    refute_match %r{<entry>}, last_response.body
  end

  test "atom feed with a single gem" do
    push File.join('.', 'samples', 'geminabox-0.12.4.gem')

    get("/atom.xml").body

    assert last_response.ok?
    feed_content = RSS::Parser.parse(last_response.body)
    feed_content.items.size == 1
  end
end
