require 'test_helper'

module Geminabox
  class HttpDummyTest < Minitest::Test

    def setup
      @default = 'foo bar'
      @http_dummy = HttpDummy.new
      @http_dummy.default_response = @default
    end

    def test_get_content
      assert_equal @default, @http_dummy.get_content('http://example.com')
    end

    def test_get
      response = @http_dummy.get('http://example.com')
      assert_equal @default, response.body
      assert_equal @default, response.status
      assert_equal @default, response.code
    end

    def test_post
      response = @http_dummy.post('http://example.com')
      assert_equal @default, response.body
      assert_equal @default, response.status
      assert_equal @default, response.code
    end

    def test_set_auth
      assert_equal true, @http_dummy.set_auth('http://example', 'foo', 'bar')
    end

  end
end
