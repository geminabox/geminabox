require_relative '../../test_helper'
module Geminabox
  class GemStoreErrorTest < Minitest::Test
    def test_error
      reason = "This message"
      code = 500
      begin
        raise GemStoreError.new(500, reason)
      rescue GemStoreError => error
        assert_equal(code, error.code)
        assert_equal(reason, error.reason)
      end
    end
  end
end
