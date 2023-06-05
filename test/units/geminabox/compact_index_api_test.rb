require_relative '../../test_helper'

module Geminabox
  class CompactIndexApiTest < Minitest::Test

    def setup
      clean_data_dir
      inject_gems do |builder|
        builder.gem "b"
        builder.gem "z"
      end
      @api = CompactIndexApi.new
      @remote_api = Minitest::Mock.new
      @api.instance_variable_set :@api, @remote_api
      @api.cache.flush_all
      reindex
    end

    def teardown
      Geminabox.rubygems_proxy = false
    end

    def reindex
      Indexer.new.reindex(:force_rebuild)
      CompactIndexer.new.reindex
      assert @api.local_versions
    end

    def local_names
      %w[--- b z].join("\n") << "\n"
    end

    def remote_names
      %w[--- a r].join("\n") << "\n"
    end

    def combined_names
      %w[--- a b r z].join("\n") << "\n"
    end

    def remote_versions
      a = "a 1.0.0 4f94d7e65f1e7e55b5bfcf7334449d8f"
      r = "r 1.0.0 c6009f08fc5fc6385f1ea1f5840e179f"
      "created_at: 2022-07-06T04:58:59.448+0000\n---\n#{a}\n#{r}\n"
    end

    def conflicting_remote_versions
      b = "a 2.0.0 4f94d7e65f1e7e55b5bfcf7334449d8f"
      z = "z 2.0.0 c6009f08fc5fc6385f1ea1f5840e179f"
      "created_at: 2022-07-06T04:58:59.448+0000\n---\n#{b}\n#{z}\n"
    end

    def test_local_versions_returns_nil_before_the_first_reindex
      clean_data_dir
      inject_gems do |builder|
        builder.gem "x"
      end
      refute CompactIndexApi.new.local_versions
    end

    def test_local_for_standalone_server
      assert_equal local_names, @api.names
    end

    def test_remote_names
      Geminabox.rubygems_proxy = true

      @remote_api.expect(:fetch_names, [200, remote_names], [nil])
      assert_equal combined_names, @api.names
      @remote_api.verify
    end

    def test_remote_names_when_already_cached
      Geminabox.rubygems_proxy = true

      @api.cache.store("names", remote_names)
      etag = @api.cache.md5("names")
      @remote_api.expect(:fetch_names, [304, remote_names], [etag])
      assert_equal combined_names, @api.names
      @remote_api.verify
    end

    def test_local_versions
      local_versions = @api.versions
      assert_match(/b 1.0.0 \S{32}\nz 1.0.0 \S{32}\n/, local_versions)
    end

    def test_remote_versions
      Geminabox.rubygems_proxy = true
      @remote_api.expect(:fetch_versions, [200, remote_versions], [nil])
      combined_versions = @api.versions
      assert_match(/a 1.0.0 \S{32}\nb 1.0.0 \S{32}\nr 1.0.0 \S{32}\nz 1.0.0 \S{32}\n/, combined_versions)
      @remote_api.verify
    end

    def test_remote_versions_when_already_cached
      Geminabox.rubygems_proxy = true

      @api.cache.store("versions", remote_versions)
      etag = @api.cache.md5("versions")
      @remote_api.expect(:fetch_versions, [304, remote_versions], [etag])
      combined_versions = @api.versions
      assert_match(/a 1.0.0 \S{32}\nb 1.0.0 \S{32}\nr 1.0.0 \S{32}\nz 1.0.0 \S{32}\n/, combined_versions)
      @remote_api.verify
    end

    def test_local_info
      reindex
      local_info = @api.info("b")
      assert_match(/---\n1.0.0 |checksum:\S{64}/, local_info)
    end

    def test_remote_info
      Geminabox.rubygems_proxy = true

      remote_info = "--\nr 1.0.0 whatever\n"
      @remote_api.expect(:fetch_info, [200, remote_info], ["r", nil])
      assert_equal remote_info, @api.info("r")
      @remote_api.verify
    end

    def test_remote_info_when_already_cached
      Geminabox.rubygems_proxy = true

      remote_info = "--\n1.0.0 |checksum:whatever\n"
      @api.cache.store("info/r", remote_info)
      etag = @api.cache.md5("info/r")
      @remote_api.expect(:fetch_info, [304, remote_info], ["r", etag])
      assert_equal remote_info, @api.info("r")
      @remote_api.verify
    end

    def test_local_info_takes_precedence_when_configured
      Geminabox.rubygems_proxy = true
      reindex
      remote_info = "--\n1.0.0 |checksum:whatever\n"
      @remote_api.expect(:fetch_info, [304, remote_info], ["b", nil])
      local_info = @api.info("b")
      assert_match(/---\n1.0.0 |checksum:\S{64}/, local_info)
    end

    def test_local_versions_take_precedence_when_configured
      Geminabox.rubygems_proxy = true
      reindex

      @remote_api.expect(:fetch_versions, [200, conflicting_remote_versions], [nil])
      versions = @api.versions
      assert_match(/\Acreated_at:.+\n---\na 2.0.0 \S{32}\nb 1.0.0 \S{32}\nz 1.0.0 \S{32}\nz 2.0.0 \S{32}\n\z/, versions)
      @remote_api.verify
    end

    def proxied_remote_versions(versions:, checksum:)
      b = "b #{versions} #{checksum}"
      "created_at: 2022-07-06T04:58:59.448+0000\n---\n#{b}\n"
    end

    def test_moving_a_locally_stored_proxied_gem_to_the_proxy_cache_and_back_again
      Geminabox.rubygems_proxy = true
      reindex

      local_gem_info = @api.local_gem_info("b")
      checksum = Digest::MD5.hexdigest(local_gem_info)
      remote_versions = proxied_remote_versions(versions: "1.0.0", checksum: checksum)

      @remote_api.expect(:fetch_versions, [200, remote_versions], [nil])
      @remote_api.expect(:fetch_info, [200, local_gem_info], ["b", nil])
      refute @api.cache.read("gems/b-1.0.0.gem")
      refute @api.cache.read("gems/z-1.0.0.gem")

      @api.remove_proxied_gems_from_local_index

      assert @api.cache.read("gems/b-1.0.0.gem")
      refute @api.cache.read("gems/z-1.0.0.gem")
      @remote_api.verify

      @api.move_gems_from_proxy_cache_to_local_index
      refute @api.cache.read("gems/b-1.0.0.gem")
    end

    def test_locally_stored_gems_with_non_overlapping_versions_on_the_remote_server_are_not_moved
      Geminabox.rubygems_proxy = true

      reindex

      remote_gem_info = "---\n2.0.0 |checksum:someother\n"
      checksum = Digest::MD5.hexdigest(remote_gem_info)
      remote_versions = proxied_remote_versions(versions: "1.0.0", checksum: checksum)

      @remote_api.expect(:fetch_versions, [200, remote_versions], [nil])
      @remote_api.expect(:fetch_info, [200, remote_gem_info], ["b", nil])

      @api.remove_proxied_gems_from_local_index
      refute @api.cache.read("gems/b-1.0.0.gem")
      refute @api.cache.read("gems/z-1.0.0.gem")
      @remote_api.verify
    end

    def test_locally_stored_gems_with_additional_local_versions_are_not_moved
      Geminabox.rubygems_proxy = true

      inject_gems do |builder|
        builder.gem "b", version: "2.0.0"
      end

      reindex

      info = DependencyInfo.new("b")
      info.content = @api.local_gem_info("b")
      assert_equal ["1.0.0", "2.0.0"], info.version_names
      version = GemVersion.new("b", "1.0.0", "ruby")
      spec = Specs.spec_for_version(version)
      info.remove_gem_spec(spec)
      remote_gem_info = info.content

      checksum = Digest::MD5.hexdigest(remote_gem_info)
      remote_versions = proxied_remote_versions(versions: "1.0.0", checksum: checksum)

      @remote_api.expect(:fetch_versions, [200, remote_versions], [nil])
      @remote_api.expect(:fetch_info, [200, remote_gem_info], ["b", nil])

      @api.remove_proxied_gems_from_local_index
      refute @api.cache.read("gems/b-1.0.0.gem")
      refute @api.cache.read("gems/b-2.0.0.gem")
      refute @api.cache.read("gems/z-1.0.0.gem")
      @remote_api.verify
    end

    def test_reporting_proxy_status
      status_and_conflicts = [
        ["a", :local, nil],
        ["b", :proxied, nil],
        ["c", :disjoint, ["1.0"]],
        ["d", :conflicts, ["2.0", "3.0"]]
      ]
      @api.instance_eval do
        def say(msg)
          @messages << msg
        end
      end
      @api.instance_variable_set(:@messages, [])
      @api.report_proxy_status(status_and_conflicts)
      expected = ["a: local", "b: proxied", "c: disjoint: 1.0", "d: conflicts: 2.0, 3.0"]
      assert_equal expected, @api.instance_variable_get(:@messages)
    end
  end
end
