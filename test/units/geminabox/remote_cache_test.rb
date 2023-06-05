require_relative '../../test_helper'

module Geminabox
  class RemoteCacheTest < Minitest::Test

    def setup
      clean_data_dir
      @cache = RemoteCache.new
      @paths = %w[gems/foobar-1.0.0.gem info/foobar versions names]
    end

    def create_entries
      @paths.each { |path| @cache.store(path, path) }
    end

    def test_trying_to_read_nonexistent_files_returns_nil
      @paths.each { |path| assert_nil @cache.read(path) }
    end

    def test_trying_to_retrieve_the_md5_hash_of_nonexistent_files_returns_nil
      @paths.each { |path| assert_nil @cache.md5(path) }
    end

    def test_reading_files_returns_their_content
      create_entries
      @paths.each { |path| assert_equal path, @cache.read(path) }
    end

    def test_flushing_individual_files_deletes_them
      create_entries
      @paths.each do |path|
        @cache.flush(path)
        assert_nil @cache.read(path)
        assert_nil @cache.md5(path)
      end
    end

    def test_flushing_all_files_deletes_them
      create_entries
      @cache.flush_all
      @paths.each do |path|
        assert_nil @cache.read(path)
        assert_nil @cache.md5(path)
      end
    end

    def test_reading_md5_hashes
      create_entries
      @paths.each { |path| assert_equal Digest::MD5.hexdigest(path), @cache.md5(path) }
    end

    def test_caching_data
      @cache.cache("info/rake") { "boohoo" }
      assert_equal "boohoo", @cache.read("info/rake")
      assert_equal Digest::MD5.hexdigest("boohoo"), @cache.md5("info/rake")
    end

  end
end
