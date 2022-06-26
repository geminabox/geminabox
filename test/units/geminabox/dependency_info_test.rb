require_relative '../../test_helper'
module Geminabox
  class DependencyInfoTest < Minitest::Test

    # rubocop:disable Lint/Syntax
    def content
      <<~DATA
---
4.0.0 cucumber:< 4.0&>= 2.0,gherkin:< 6.0&>= 4.0,yard:>= 0.8.1&~> 0.8 |checksum:e6804d824830d345f065c55c667f9b9b52e4edd775b3396940cc51d4b0dd4d22
5.0.0 cucumber:< 4.0&>= 2.0,gherkin:< 6.0&>= 4.0,yard:>= 0.8.1&~> 0.8 |checksum:e75e01a40c87215d75f6523e13c7ec4af4018297c82de642b9c5f8f94e19072d
5.0.1 cucumber:>= 0,gherkin:>= 0,yard:>= 0 |checksum:237c67ccba4d74905a3839bad4e50912023e03cc25273bca72887492254fb5dd
5.1.0.pre.mrt cucumber:>= 0,gherkin:>= 0,yard:>= 0 |checksum:8d3e29663c5db65e2f10d8b4622685aa8a29e1465530b6f47be62ef891160415,rubygems:> 1.3.1
5.2.1 |checksum:8d3e29663c5db65e2f10d8b4622685aa8a29e1465530b6f47be62ef891160415
      DATA
    end
    # rubocop:enable Lint/Syntax

    def versions
      [
        ["4.0.0", nil, [["cucumber", ["< 4.0", ">= 2.0"]], ["gherkin", ["< 6.0", ">= 4.0"]], ["yard", [">= 0.8.1", "~> 0.8 "]]],
         [["checksum", ["e6804d824830d345f065c55c667f9b9b52e4edd775b3396940cc51d4b0dd4d22"]]]],
        ["5.0.0", nil, [["cucumber", ["< 4.0", ">= 2.0"]], ["gherkin", ["< 6.0", ">= 4.0"]], ["yard", [">= 0.8.1", "~> 0.8 "]]],
         [["checksum", ["e75e01a40c87215d75f6523e13c7ec4af4018297c82de642b9c5f8f94e19072d"]]]],
        ["5.0.1", nil, [["cucumber", [">= 0"]], ["gherkin", [">= 0"]], ["yard", [">= 0 "]]],
         [["checksum", ["237c67ccba4d74905a3839bad4e50912023e03cc25273bca72887492254fb5dd"]]]],
        ["5.1.0.pre.mrt", nil, [["cucumber", [">= 0"]], ["gherkin", [">= 0"]], ["yard", [">= 0 "]]],
         [["checksum", ["8d3e29663c5db65e2f10d8b4622685aa8a29e1465530b6f47be62ef891160415"]], ["rubygems", ["> 1.3.1"]]]],
        ["5.2.1", nil, [], [["checksum", ["8d3e29663c5db65e2f10d8b4622685aa8a29e1465530b6f47be62ef891160415"]]]]
      ]
    end

    def test_decoding_content
      info = DependencyInfo.new("test")
      info.content = content
      assert_equal 5, info.versions.size
      (0..4).each do |i|
        assert_equal versions[i], info.versions[i]
      end
    end

    def test_encoding_versions
      info = DependencyInfo.new("test")
      info.versions = versions
      assert_equal content, info.content
    end

    def test_adding_a_valid_gem_spec
      info = DependencyInfo.new("test")
      spec = Gem::Specification.new do |s|
        s.name = "test"
        s.version = "3.0.0"
        s.add_dependency("cucumber", ["< 3.0", ">= 2.2.8"])
        s.add_dependency("gherkin", [">= 7.3", "< 8.9"])
        s.add_dependency("yard", [">= 3.2", "< 5"])
        s.platform = 'java'
      end
      info.add_gem_spec_and_gem_checksum(spec, "foofoofoo")
      expected = ["3.0.0", "java", [["cucumber", ["< 3.0", ">= 2.2.8"]], ["gherkin", ["< 8.9", ">= 7.3"]], ["yard", ["< 5", ">= 3.2"]]], [["checksum", "foofoofoo"]]]
      assert_equal(expected, info.versions[0])
      assert info.content
    end

    def test_returns_empty_version_list
      info = DependencyInfo.new("test")
      assert_equal [], info.versions
    end

    def test_can_encode_empty_content
      info = DependencyInfo.new("test")
      assert_equal "---\n", info.content
    end

    def test_version_names
      info = DependencyInfo.new("test")
      spec = Gem::Specification.new do |s|
        s.name = "test"
        s.version = "1.1.0"
      end
      info.add_gem_spec_and_gem_checksum(spec, "checksum1")
      spec = Gem::Specification.new do |s|
        s.name = "test"
        s.version = "1.1.0"
        s.platform = "java"
      end
      info.add_gem_spec_and_gem_checksum(spec, "checksum2")
      expected = ["1.1.0", "1.1.0-java"]
      assert_equal expected, info.version_names
    end

  end
end
