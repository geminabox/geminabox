require_relative '../../test_helper'

module Geminabox
  class IndexerTest < Minitest::Test

    def setup
      clean_data_dir
      @indexer = Indexer.new(Geminabox.data)
      @compact_indexer = Minitest::Mock.new
      @indexer.instance_variable_set :@compact_indexer, @compact_indexer
      assert Geminabox.incremental_updates
    end

    def test_incremental_reindexing_without_existing_indexes_performs_a_full_reindex
      add_gem("foo")

      @compact_indexer.expect(:reindex, true)
      reindex
      @compact_indexer.verify
    end

    def test_errors_on_incremental_indexing_cause_a_full_reindex
      add_gem("foo")

      Indexer.stub(:updated_gemspecs, proc { raise "boohoo" }) do
        @compact_indexer.expect(:reindex, true)
        silence { @indexer.reindex }
        @compact_indexer.verify
      end
    end

    def test_full_reindexing_creates_indexes_and_compressed_gemspecs
      foo_spec = add_gem("foo")
      bar_spec = add_gem("bar")
      pre_spec = add_gem("pre", version: "1.0.0.pre1")

      @compact_indexer.expect(:reindex, true)
      reindex(:force_rebuild)
      @compact_indexer.verify

      assert File.exist?(quick_spec_file(foo_spec))
      assert File.exist?(quick_spec_file(bar_spec))
      assert File.exist?(quick_spec_file(pre_spec))

      assert_indexes_exist

      all_specs, latest_specs, prerelease_specs = load_indexes
      assert_equal [["bar", Gem::Version.new("1.0.0"), "ruby"], ["foo", Gem::Version.new("1.0.0"), "ruby"]], all_specs
      assert_equal [["bar", Gem::Version.new("1.0.0"), "ruby"], ["foo", Gem::Version.new("1.0.0"), "ruby"]], latest_specs
      assert_equal [["pre", Gem::Version.new("1.0.0.pre1"), "ruby"]], prerelease_specs
    end

    def test_incremental_reindexing_creates_indexes_and_compressed_gemspecs
      @compact_indexer.expect(:reindex, true)
      reindex(:force_rebuild)
      @compact_indexer.verify

      foo_spec = add_gem("foo")
      bar_spec = add_gem("bar")
      pre_spec = add_gem("pre", version: "1.0.0.pre1")

      @compact_indexer.expect(:reindex, true) do |specs|
        specs.map(&:name).sort == %w[foo bar pre].sort
      end
      reindex
      @compact_indexer.verify

      assert File.exist?(quick_spec_file(foo_spec))
      assert File.exist?(quick_spec_file(bar_spec))
      assert File.exist?(quick_spec_file(pre_spec))

      assert_indexes_exist

      all_specs, latest_specs, prerelease_specs = load_indexes
      assert_equal [["bar", Gem::Version.new("1.0.0"), "ruby"], ["foo", Gem::Version.new("1.0.0"), "ruby"]], all_specs
      assert_equal [["bar", Gem::Version.new("1.0.0"), "ruby"], ["foo", Gem::Version.new("1.0.0"), "ruby"]], latest_specs
      assert_equal [["pre", Gem::Version.new("1.0.0.pre1"), "ruby"]], prerelease_specs
    end

    def test_yanking_removes_compressed_gemspecs
      foo_spec = add_gem("foo")
      bar_spec = add_gem("bar")
      pre_spec = add_gem("pre", version: "1.0.0.pre1")

      @compact_indexer.expect(:reindex, true)
      reindex(:force_rebuild)
      @compact_indexer.verify

      assert_indexes_exist

      assert File.exist?(quick_spec_file(foo_spec))
      assert File.exist?(quick_spec_file(bar_spec))

      @compact_indexer.expect(:yank, true) { |spec| spec.name == "foo" }
      @compact_indexer.expect(:yank, true) { |spec| spec.name == "pre" }
      @indexer.yank(gemfile_path(foo_spec))
      @indexer.yank(gemfile_path(pre_spec))
      @compact_indexer.verify

      assert_indexes_exist

      refute File.exist?(quick_spec_file(foo_spec))
      assert File.exist?(quick_spec_file(bar_spec))
      refute File.exist?(quick_spec_file(pre_spec))

      all_specs, latest_specs, prerelease_specs = load_indexes
      assert_equal [["bar", Gem::Version.new("1.0.0"), "ruby"]], all_specs
      assert_equal [["bar", Gem::Version.new("1.0.0"), "ruby"]], latest_specs
      assert_equal [], prerelease_specs
    end

    def reindex(*args)
      silence_stream($stdout) do
        @indexer.reindex(*args)
      end
    end

    def add_gem(name, options = {})
      factory = GemFactory.new(File.join(Geminabox.data, "gems"))
      path = silence { factory.gem(name, options) }
      Gem::Package.new(path.to_s).spec
    end

    def quick_spec_file(spec)
      version = GemVersion.from_spec(spec)
      Specs.spec_file_name_for_version(version)
    end

    def gemfile_path(spec)
      version = GemVersion.from_spec(spec)
      File.join(File.join(Geminabox.data, "gems", "#{version.gemfile_name}.gem"))
    end

    def assert_indexes_exist
      assert File.exist?(File.join(Geminabox.data, "specs.4.8"))
      assert File.exist?(File.join(Geminabox.data, "specs.4.8.gz"))
      assert File.exist?(File.join(Geminabox.data, "latest_specs.4.8"))
      assert File.exist?(File.join(Geminabox.data, "latest_specs.4.8.gz"))
      assert File.exist?(File.join(Geminabox.data, "prerelease_specs.4.8"))
      assert File.exist?(File.join(Geminabox.data, "prerelease_specs.4.8.gz"))
    end

    def load_indexes
      all_specs = @indexer.load_index(File.join(Geminabox.data, "specs.4.8"))
      latest_specs = @indexer.load_index(File.join(Geminabox.data, "latest_specs.4.8"))
      prerelease_specs = @indexer.load_index(File.join(Geminabox.data, "prerelease_specs.4.8"))
      [all_specs, latest_specs, prerelease_specs]
    end

  end
end
