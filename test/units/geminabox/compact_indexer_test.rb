require_relative '../../test_helper'

module Geminabox
  class CompactIndexerTest < Minitest::Test

    def setup
      clean_data_dir
      @indexer = CompactIndexer.new(Geminabox.data)
    end

    def test_info_path_exists
      assert File.exist?(@indexer.info_path)
    end

    def test_version_path_does_not_exist
      refute File.exist?(@indexer.versions_path)
      refute @indexer.fetch_versions
    end

    def load_versions
      assert File.exist?(@indexer.versions_path)
      VersionInfo.new.tap do |info|
        info.load_versions(@indexer.versions_path)
      end
    end

    def test_full_reindex_with_no_gems_creates_empty_versions_file
      silence_stream($stdout) do
        @indexer.reindex
      end
      version_info = load_versions

      assert version_info.versions.empty?
      assert version_info.digests.empty?
    end

    def test_full_reindex_with_gems_creates_index_files
      add_gem("foobar")
      add_gem("goofy")

      silence_stream($stdout) do
        Gem::Indexer.new(TEST_DATA_DIR).generate_index
        @indexer.reindex
      end
      version_info = load_versions

      refute version_info.versions.empty?
      refute version_info.digests.empty?
      assert @indexer.fetch_info("foobar")
      assert @indexer.fetch_info("goofy")
    end

    def test_adding_a_new_gem_to_an_existing_index
      VersionInfo.new.write(@indexer.versions_path)

      spec, digest = add_gem("foobar")
      silence_stream($stdout) do
        @indexer.reindex([spec])
      end

      version_info = load_versions

      info_name_path = @indexer.info_name_path("foobar")
      assert File.exist?(info_name_path)

      info = DependencyInfo.new("foobar")
      info.content = File.read(info_name_path)
      assert_equal [["1.0.0", nil, [], [["checksum", [digest]]]]], info.versions

      assert_equal "1.0.0", version_info.versions["foobar"]
      assert_equal info.digest, version_info.digests["foobar"]
    end

    def test_removing_a_gem_from_the_index
      VersionInfo.new.write(@indexer.versions_path)

      spec = add_gem("foobar").first
      silence_stream($stdout) do
        @indexer.reindex([spec])
        @indexer.yank(spec)
      end

      version_info = load_versions
      info_name_path = @indexer.info_name_path("foobar")
      refute File.exist?(info_name_path)

      assert version_info.versions.empty?
      assert version_info.digests.empty?
    end

    def add_gem(name, options = {})
      factory = GemFactory.new(File.join(Geminabox.data, "gems"))
      path = silence { factory.gem(name, options) }
      digest = Digest::SHA256.file(path).hexdigest
      spec = Gem::Package.new(path.to_s).spec
      [spec, digest]
    end
  end
end
