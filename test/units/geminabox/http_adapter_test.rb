require_relative '../../test_helper'

module Geminabox
  class HttpAdapterTest < Minitest::Test
    def http_adapter
      @http_handler ||= HttpAdapter.new
    end

    def test_get_content
      assert_raises HttpAdapterConfigError do
        http_adapter.get_content('http://example.com')
      end
    end

    def test_get
      assert_raises HttpAdapterConfigError do
        http_adapter.get('http://example.com')
      end
    end

    def test_post
      assert_raises HttpAdapterConfigError do
        http_adapter.post('http://example.com')
      end
    end

    def test_set_auth
      assert_raises HttpAdapterConfigError do
        http_adapter.set_auth('http://example', 'foo', 'bar')
      end
    end

    def test_default_geminabox_http_adapter
      assert_kind_of HttpClientAdapter, Geminabox.http_adapter
    end
  end
end
