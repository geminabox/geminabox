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
    push fixture('geminabox-0.12.4.gem')

    get "/atom.xml"

    assert last_response.ok?
    feed_content = RSS::Parser.parse(last_response.body)
    feed_content.items.size == 1
  end
end

class DeletingEntireGemCollection < Minitest::Test
  include GeminaboxSystemTest
  
  def setup
    delete("/api/v1/gems")
  end

  test "after deleting all, collection is empty" do
    push fixture('geminabox-0.12.4.gem')

    delete("/api/v1/gems")
    
    gem_list = JSON.parse(get("/api/v1/gems").body)

    assert gem_list.empty?, "Expected the gem collection to be empty after deleting it, but it has <#{gem_list.size}> items."
  end

  test "that deletes are idempotent" do
    push fixture('geminabox-0.12.4.gem')

    assert delete("/api/v1/gems").ok?
    assert delete("/api/v1/gems").ok?
  end
end
