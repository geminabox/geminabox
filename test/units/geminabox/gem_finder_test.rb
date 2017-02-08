require 'test_helper'
module Geminabox
  class GemFinderTest < Minitest::Test
    def setup
      clean_data_dir
    end

    def test_find_by_name
      inject_gems do |builder|
        builder.gem "target", version: "0.0.1"
        builder.gem "target", version: "0.0.2"
        builder.gem "other" , version: "0.0.1"
      end

      actual = Geminabox::GemFinder.find_by_name("target")

      assert_equal 2, actual.size
      assert_includes actual, Geminabox::GemVersion.new("target", "0.0.1", "ruby")
      assert_includes actual, Geminabox::GemVersion.new("target", "0.0.2", "ruby")
    end

    def test_find_by_name_when_exists_hyphens_including_gem
      inject_gems do |builder|
        builder.gem "forked-unicorn"              , version: "0.0.1"
        builder.gem "forked-unicorn"              , version: "0.0.2"
        builder.gem "forked-unicorn-worker-killer", version: "0.0.1"
      end

      actual = Geminabox::GemFinder.find_by_name("forked-unicorn")

      assert_equal 2, actual.size
      assert_includes actual, Geminabox::GemVersion.new("forked-unicorn", "0.0.1", "ruby")
      assert_includes actual, Geminabox::GemVersion.new("forked-unicorn", "0.0.2", "ruby")
    end
  end
end
