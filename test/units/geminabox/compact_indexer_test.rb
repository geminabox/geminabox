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

  # Replaces the already-stored a-1.0.0.gem with a fresh build that declares
  # different dependencies. GemFactory skips building when the target file
  # exists, so the replacement is produced in a separate directory and copied
  # over the stored gem with a current mtime.
  def replace_gem_a
    Dir.mktmpdir do |other|
      replacement = GemFactory.new(other).gem("a", deps: { c: ">= 2.0" })
      dest = File.join(Geminabox.data, "gems", "a-1.0.0.gem")
      FileUtils.cp(replacement, dest)
      File.utime(Time.now, Time.now, dest)
    end
    Gem::Indexer.new(Geminabox.data).generate_index
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

    assert_equal "---\n1.0.0 |checksum:#{gem_sha256('b-1.0.0.gem')}\n",
                 File.read(@indexer.info_path("b"))
    assert_equal "---\n1.0.0 b:>= 1.0|checksum:#{gem_sha256('a-1.0.0.gem')}\n",
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

  test "uploading a new version appends to versions.list" do
    build_index { |builder| builder.gem "a" }
    original = File.read(@indexer.versions_path)

    inject_gems { |builder| builder.gem "a", version: "2.0.0" }
    @indexer.reindex

    updated = File.read(@indexer.versions_path)
    assert updated.start_with?(original), "versions.list must be append-only"
    info = File.read(@indexer.info_path("a"))
    assert_match(/^2\.0\.0 /, info)
    assert_equal "a 2.0.0 #{Digest::MD5.hexdigest(info)}", updated.split("\n").last
  end

  test "reindex without changes appends nothing" do
    build_index { |builder| builder.gem "a" }
    before = File.read(@indexer.versions_path)
    @indexer.reindex
    assert_equal before, File.read(@indexer.versions_path)
  end

  test "deleting a version appends a yank line and rewrites info" do
    build_index do |builder|
      builder.gem "a"
      builder.gem "a", version: "2.0.0"
    end
    original = File.read(@indexer.versions_path)

    File.delete File.join(Geminabox.data, "gems", "a-2.0.0.gem")
    Gem::Indexer.new(Geminabox.data).generate_index
    @indexer.reindex

    updated = File.read(@indexer.versions_path)
    assert updated.start_with?(original)
    info = File.read(@indexer.info_path("a"))
    refute_match(/^2\.0\.0 /, info)
    assert_equal "a -2.0.0 #{Digest::MD5.hexdigest(info)}", updated.split("\n").last
  end

  test "deleting the last version leaves a bare info file and drops the name" do
    build_index do |builder|
      builder.gem "a"
      builder.gem "b"
    end

    File.delete File.join(Geminabox.data, "gems", "a-1.0.0.gem")
    Gem::Indexer.new(Geminabox.data).generate_index
    @indexer.reindex

    assert_equal "---\n", File.read(@indexer.info_path("a"))
    assert_equal "---\nb\n", File.read(@indexer.names_path)
    assert_equal "a -1.0.0 #{Digest::MD5.hexdigest("---\n")}",
                 File.read(@indexer.versions_path).split("\n").last
  end

  test "names file gains new gems on reconcile" do
    build_index { |builder| builder.gem "a" }
    inject_gems { |builder| builder.gem "b" }
    @indexer.reindex
    assert_equal "---\na\nb\n", File.read(@indexer.names_path)
  end

  test "an unparseable versions.list triggers a from-scratch rebuild" do
    build_index { |builder| builder.gem "a" }
    File.write(@indexer.versions_path, "garbage")
    @indexer.reindex
    lines = File.read(@indexer.versions_path).split("\n")
    assert_match(/\Acreated_at: /, lines[0])
    assert_equal "---", lines[1]
    assert_match(/\Aa 1\.0\.0 [0-9a-f]{32}\z/, lines[2])
  end

  test "every versions.list checksum matches its info file bytes" do
    build_index do |builder|
      builder.gem "a", deps: { b: ">= 1.0" }
      builder.gem "c"
    end
    inject_gems { |builder| builder.gem "a", version: "2.0.0" }
    @indexer.reindex
    File.delete File.join(Geminabox.data, "gems", "c-1.0.0.gem")
    Gem::Indexer.new(Geminabox.data).generate_index
    @indexer.reindex

    last_checksum = {}
    File.read(@indexer.versions_path).split("\n").drop(2).each do |line|
      name, _versions, md5 = line.split
      last_checksum[name] = md5
    end
    last_checksum.each do |name, md5|
      assert_equal Digest::MD5.hexdigest(File.read(@indexer.info_path(name))), md5,
                   "info/#{name} bytes must hash to the last versions.list checksum"
    end
  end

  test "replacing a same-version gem refreshes its info and appends a touch line" do
    build_index { |builder| builder.gem "a", deps: { b: ">= 1.0" } }
    original = File.read(@indexer.versions_path)
    assert_match(/b:>= 1\.0/, File.read(@indexer.info_path("a")))

    replace_gem_a
    @indexer.reindex

    updated = File.read(@indexer.versions_path)
    assert updated.start_with?(original), "versions.list must be append-only"
    info = File.read(@indexer.info_path("a"))
    assert_match(/c:>= 2\.0/, info)
    refute_match(/b:>= 1\.0/, info)
    assert_equal "a -1.0.0,1.0.0 #{Digest::MD5.hexdigest(info)}",
                 updated.split("\n").last
  end

  test "reconcile after replacement stays idempotent" do
    build_index { |builder| builder.gem "a", deps: { b: ">= 1.0" } }
    replace_gem_a
    @indexer.reindex
    before = File.read(@indexer.versions_path)
    @indexer.reindex
    assert_equal before, File.read(@indexer.versions_path)
  end

  test "published index files are world-readable within the umask" do
    build_index { |builder| builder.gem "a" }
    expected = 0o644 & ~File.umask
    assert_equal expected, File.stat(@indexer.versions_path).mode & 0o777
    assert_equal expected, File.stat(@indexer.info_path("a")).mode & 0o777
  end

  test "Server.reindex(:force_rebuild) refreshes the compact index" do
    GemFactory.new(File.join(Geminabox.data, "gems")).gem("a")
    Geminabox::Server.reindex(:force_rebuild)
    assert_match(/^a 1\.0\.0 /, File.read(@indexer.versions_path))
  end

  test "incremental Server.reindex appends new versions" do
    build_index { |builder| builder.gem "a" }
    before = File.read(@indexer.versions_path)

    GemFactory.new(File.join(Geminabox.data, "gems")).gem("a", version: "2.0.0")
    Geminabox::Server.reindex

    after = File.read(@indexer.versions_path)
    assert after.start_with?(before), "incremental reindex must append"
    assert_match(/\Aa 2\.0\.0 [0-9a-f]{32}\z/, after.split("\n").last)
  end
end
