require_relative '../test_helper'
require 'rack/test'
require 'rss/atom'

class GemDeletionPreconditionsTest < Minitest::Test
  include Rack::Test::Methods

  def setup
    clean_data_dir
  end

  def app
    Geminabox::Server
  end

  test "gems can not be deleted via web ui when prohibited by configuration" do
    Geminabox.stub(:allow_delete, false) do
      delete "/gems/foo-1.0.0.gem"
      assert last_response.forbidden?
    end
  end

  test "gems can not be yanked via gem cutter apiprohibited by configuration" do
    Geminabox.stub(:allow_delete, false) do
      delete "/api/v1/gems/yank"
      assert last_response.forbidden?
    end
  end
end
