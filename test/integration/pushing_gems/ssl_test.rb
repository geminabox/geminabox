require_relative '../../test_helper'

class SSLTest < Geminabox::TestCase
  url "https://localhost/"
  ssl true
  should_push_gem
  # test "s" do
  #   puts url_for("/")
  #   sleep 1000
  # end
end
