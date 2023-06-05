require_relative '../../test_helper'

module Geminabox
  class VersionInfoTest < Minitest::Test

    def expected_versions
      {
        "example" => "1.0.0",
        "gem_with_dependencies" => "3.0.0",
        "requirements" => "3.0.0",
        "test_multiple" => "1.0.0"
      }
    end

    def expected_digests
      {
        "example" => "0843d12079d52bb165316f4b543c110d",
        "gem_with_dependencies" => "ada5ba50b78d1df4b9e1709e88b2941b",
        "requirements" => "d23cc69decc95924088599b2c13aaed2",
        "test_multiple" => "395fba1907dce2578a3ed27449ab13fd"
      }
    end

    def versions_file
      fixture("versions.txt")
    end

    def versions_from_fixture_file
      info = VersionInfo.new
      info.load_versions(versions_file)
      info
    end

    def test_loading_versions
      info = versions_from_fixture_file
      assert_equal expected_versions, info.versions
      assert_equal expected_digests, info.digests
      assert_equal File.read(versions_file).split("\n")[2..-1], info.content.split("\n")[2..-1]
    end

    def test_adding_empty_dependency_info_removes_gem
      info = versions_from_fixture_file

      assert info.versions["example"]
      assert info.digests["example"]

      info.update_gem_versions(DependencyInfo.new("example"))

      assert_nil info.versions["example"]
      assert_nil info.digests["example"]
    end

    def test_adding_an_updated_dependency_info_updates_versions_and_digest
      version_info = versions_from_fixture_file

      assert version_info.versions["example"]
      assert version_info.digests["example"]

      dep_info = DependencyInfo.new("example")
      spec1 = Gem::Specification.new do |s|
        s.name = "example"
        s.version = "1.0.0"
      end
      spec2 = Gem::Specification.new do |s|
        s.name = "example"
        s.version = "1.1.0"
      end
      dep_info.add_gem_spec_and_gem_checksum(spec1, "foobar1")
      dep_info.add_gem_spec_and_gem_checksum(spec2, "foobar2")

      version_info.update_gem_versions(dep_info)

      assert_equal "1.0.0,1.1.0", version_info.versions["example"]
      assert_equal dep_info.digest, version_info.digests["example"]
    end

    def test_can_write_version_file
      dest = Tempfile.new('foo')
      dest.close
      version_info = versions_from_fixture_file
      version_info.write(dest.path)
      assert_equal File.read(versions_file).split("\n")[2..-1], File.read(dest.path).split("\n")[2..-1]
    ensure
      dest.unlink
    end

  end
end
