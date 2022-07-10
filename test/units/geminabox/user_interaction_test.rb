require_relative '../../test_helper'
module Geminabox
  class GemVersionCollectionTest < Minitest::Test
    def setup
      Gem::DefaultUserInteraction.ui = Gem::ConsoleUI.new
    end

    def teardown
      Gem::DefaultUserInteraction.ui = Gem::SilentUI.new
    end

    def runit(num)
      silence do
        reporter = Gem::DefaultUserInteraction.ui.progress_reporter(num, num.to_s, num.to_s)
        num.times { reporter.updated(nil) }
        reporter.done
      end
    end

    def test_progress_reporter_with_5_items
      runit(5)
    end

    def test_progress_reporter_with_100_items
      runit(100)
    end
  end
end
