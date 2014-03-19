require 'test_helper'

module Geminabox
  class HttpClientAdapterTest < Minitest::Test

    def setup
      @default = 'foo bar'
      @http_dummy = HttpClientAdapter.new
    end

    def test_get_content
      stub_request(:get, "http://example.com/").
        to_return(:status => 200, :body => @default)

      assert_equal @default, @http_dummy.get_content('http://example.com')
    end

    def test_get
      stub_request(:get, "http://example.com/").
        to_return(:status => 200, :body => @default)

      response = @http_dummy.get('http://example.com')
      assert_equal @default, response.body
      assert_equal 200, response.status
      assert_equal 200, response.code
    end

    def test_post
      stub_request(:post, "http://example.com/").
        to_return(:status => 200, :body => @default)

      response = @http_dummy.post('http://example.com')
      assert_equal @default, response.body
      assert_equal 200, response.status
      assert_equal 200, response.code
    end

    def test_set_auth
      stub_request(:get, "http://foo:bar@example.com/").
         with(:headers => {'Authorization'=>'Basic Zm9vOmJhcg=='}).
         to_return(:status => 200, :body => @default, :headers => {})

      @http_dummy.set_auth('http://example.com', 'foo', 'bar')
      assert_equal @default, @http_dummy.get_content('http://example.com')
    end

  end
end
