require 'test_helper'
require 'minitest/unit'
require 'system/geminabox_system_test'

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

    assert_equal 204, delete("/api/v1/gems").code
    assert_equal 204, delete("/api/v1/gems").code
  end
end
