require_relative '../../test_helper'

class SSLTest < Geminabox::TestCase
  url "https://127.0.0.1/"
  ssl true

  should_yank_gem
end
