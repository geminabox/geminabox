# frozen_string_literal: true

require_relative '../../test_helper'

class CompactIndexerTest < Minitest::Test
  def setup
    clean_data_dir
    @indexer = Geminabox::CompactIndexer.new
  end

  def build_index(&block)
    inject_gems(&block)
    @indexer.reindex
  end

  def gem_sha256(filename)
    Digest::SHA256.file(File.join(Geminabox.data, "gems", filename)).hexdigest
  end

  test "full build writes names sorted with a header" do
    build_index do |builder|
      builder.gem "b"
      builder.gem "a"
    end
    assert_equal "---\na\nb\n", File.read(@indexer.names_path)
  end

  test "full build renders info files with checksums and dependencies" do
    build_index do |builder|
      builder.gem "a", deps: { b: ">= 1.0" }
    end

    assert_equal "---\n1.0.0 |checksum:#{gem_sha256("b-1.0.0.gem")}\n",
                 File.read(@indexer.info_path("b"))
    assert_equal "---\n1.0.0 b:>= 1.0|checksum:#{gem_sha256("a-1.0.0.gem")}\n",
                 File.read(@indexer.info_path("a"))
  end

  test "full build joins multiple constraints with ampersands" do
    build_index do |builder|
      builder.gem "a", deps: { b: [">= 1.0", "< 3.0"] }
    end
    assert_match(/^1\.0\.0 b:< 3\.0&>= 1\.0\|checksum:/, File.read(@indexer.info_path("a")))
  end

  test "full build writes versions.list lines referencing info file md5s" do
    build_index do |builder|
      builder.gem "a", deps: { b: ">= 1.0" }
    end

    lines = File.read(@indexer.versions_path).split("\n")
    assert_match(/\Acreated_at: \d{4}-\d{2}-\d{2}T/, lines[0])
    assert_equal "---", lines[1]
    md5_a = Digest::MD5.hexdigest(File.read(@indexer.info_path("a")))
    md5_b = Digest::MD5.hexdigest(File.read(@indexer.info_path("b")))
    assert_equal ["a 1.0.0 #{md5_a}", "b 1.0.0 #{md5_b}"], lines[2..]
  end

  test "full build includes platform and prerelease versions" do
    build_index do |builder|
      builder.gem "a", version: "1.0.0", platform: "java"
      builder.gem "a", version: "2.0.0.pre"
    end
    versions = File.read(@indexer.versions_path)
    assert_match(/^a 1\.0\.0-java,2\.0\.0\.pre [0-9a-f]{32}$/, versions)
    info = File.read(@indexer.info_path("a"))
    assert_match(/^1\.0\.0-java /, info)
    assert_match(/^2\.0\.0\.pre /, info)
  end

  test "full build on an empty data dir writes a header-only versions file" do
    Gem::Indexer.new(Geminabox.data).generate_index
    @indexer.reindex
    lines = File.read(@indexer.versions_path).split("\n")
    assert_match(/\Acreated_at: /, lines[0])
    assert_equal ["---"], lines[1..]
  end
end
