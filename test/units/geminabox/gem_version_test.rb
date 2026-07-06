# frozen_string_literal: true

require_relative '../../test_helper'

class GemVersionTest < Minitest::Test
  test "number_and_platform omits the ruby platform" do
    version = Geminabox::GemVersion.new("a", "1.0.0", "ruby")
    assert_equal "1.0.0", version.number_and_platform
  end

  test "number_and_platform appends non-ruby platforms" do
    version = Geminabox::GemVersion.new("a", "1.0.0", "java")
    assert_equal "1.0.0-java", version.number_and_platform
  end

  test "number_and_platform stringifies Gem::Version numbers" do
    version = Geminabox::GemVersion.new("a", Gem::Version.new("2.0.0"), "ruby")
    assert_equal "2.0.0", version.number_and_platform
  end

  test "number_and_platform treats a nil platform as ruby" do
    version = Geminabox::GemVersion.new("a", "1.0.0", nil)
    assert_equal "1.0.0", version.number_and_platform
  end
end
