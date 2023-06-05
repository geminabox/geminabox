require_relative '../../test_helper'

module Geminabox
  class RubyGemsCompactIndexApiTest < Minitest::Test

    def setup
      @api = RubygemsCompactIndexApi.new
    end

    def teardown
      Geminabox.http_adapter = HttpClientAdapter.new
      Geminabox.allow_remote_failure = false
    end

    def stub_compact_index_request(path, body: "body", code: 200, etag: nil, exception: nil)
      headers = { 'User-Agent' => /./ }
      headers['If-None-Match'] = %("#{etag}") if etag
      stub = stub_request(:get, "https://bundler.rubygems.org/#{path}").with(headers: headers)
      if exception
        stub.to_raise(exception)
      else
        stub.to_return(status: code, body: body, headers: {})
      end
    end

    def test_get_names
      stub_compact_index_request("names")
      assert_equal [200, "body"], @api.fetch_names
    end

    def test_get_names_with_etag
      stub_compact_index_request("names", etag: "foo")
      assert_equal [200, "body"], @api.fetch_names("foo")
    end

    def test_get_versions
      stub_compact_index_request("versions")
      assert_equal [200, "body"], @api.fetch_versions
    end

    def test_get_versions_with_etag
      stub_compact_index_request("versions", etag: "foo")
      assert_equal [200, "body"], @api.fetch_versions("foo")
    end

    def test_get_info
      stub_compact_index_request("info/rake")
      assert_equal [200, "body"], @api.fetch_info("rake")
    end

    def test_get_info_with_etag
      stub_compact_index_request("info/rake", etag: "foo")
      assert_equal [200, "body"], @api.fetch_info("rake", "foo")
    end

    def test_errors_raised_from_http_adapter_return_zero_code_and_nil_body_if_remote_failures_are_allowed
      Geminabox.allow_remote_failure = true
      stub_compact_index_request("names", exception: StandardError)
      assert_equal [0, nil], @api.fetch_names("foo")
    end

    def test_errors_raised_from_http_adapter_pass_through_if_remote_failures_are_not_tolerated
      stub_compact_index_request("names", exception: StandardError)
      assert_raises(StandardError) { @api.fetch_names("foo") }
    end

  end
end
