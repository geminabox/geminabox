require_relative '../../test_helper'

module Geminabox
  class ParallelSpecReaderTest < Minitest::Test
    class TestObject
      include Geminabox::ParallelSpecReader

      attr_reader :alerted

      def alert_error(_)
        @alerted = true
      end
    end

    def test_map_gem_file_to_spec_skips_over_errors
      obj = TestObject.new
      Gem::Package.stub(:new, nil) do
        obj.map_gem_file_to_spec("foo")
      end
      assert obj.alerted
    end
  end
end
