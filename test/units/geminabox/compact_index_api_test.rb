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
    end

    def teardown
      Geminabox.rubygems_proxy = false
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

    def trigger_index_build
      assert @api.local_versions
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
      trigger_index_build
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

      remote_info = "--\nr 1.0.0 whatever\n"
      @api.cache.store("info/r", remote_info)
      etag = @api.cache.md5("info/r")
      @remote_api.expect(:fetch_info, [304, remote_info], ["r", etag])
      assert_equal remote_info, @api.info("r")
      @remote_api.verify
    end

    def test_local_info_takes_precedence_when_configured
      Geminabox.rubygems_proxy = true

      trigger_index_build

      local_info = @api.info("b")
      assert_match(/---\n1.0.0 |checksum:\S{64}/, local_info)
    end

    def test_local_versions_take_precedence_when_configured
      Geminabox.rubygems_proxy = true

      trigger_index_build

      @remote_api.expect(:fetch_versions, [200, conflicting_remote_versions], [nil])
      versions = @api.versions
      assert_match(/\Acreated_at:.+\n---\na 2.0.0 \S{32}\nb 1.0.0 \S{32}\nz 1.0.0 \S{32}\n\z/, versions)
      @remote_api.verify
    end

  end
end
