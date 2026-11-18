require_relative '../../../test_helper'

module Geminabox
  class HttpClientAdapterTest < Minitest::Test

    def setup
      @default = 'foo bar'
      @http_adapter = HttpClientAdapter.new
    end

    def test_get_content
      stub_request(:get, "http://example.com/").
        to_return(:status => 200, :body => @default)

      assert_equal @default, @http_adapter.get_content('http://example.com')
    end

    def test_get
      stub_request(:get, "http://example.com/").
        to_return(:status => 200, :body => @default)

      response = @http_adapter.get('http://example.com')
      assert_equal @default, response.body
      assert_equal 200, response.status
      assert_equal 200, response.code
    end

    def test_post
      stub_request(:post, "http://example.com/").
        to_return(:status => 200, :body => @default)

      response = @http_adapter.post('http://example.com')
      assert_equal @default, response.body
      assert_equal 200, response.status
      assert_equal 200, response.code
    end

    def test_set_auth
      stub_request(:get, "http://example.com/").
         with(:headers => {'Authorization'=>'Basic Zm9vOmJhcg=='}).
         to_return(:status => 200, :body => @default, :headers => {})

      @http_adapter.set_auth('http://example.com', 'foo', 'bar')
      assert_equal @default, @http_adapter.get_content('http://example.com')
    end

    def test_verifies_tls_certificates_by_default
      with_env(HttpAdapter::INSECURE_SKIP_TLS_VERIFY_ENV => nil) do
        mode = @http_adapter.http_client.ssl_config.verify_mode

        refute_equal 0, mode & OpenSSL::SSL::VERIFY_PEER
      end
    end

    def test_skips_tls_verification_only_when_opted_out_and_warns
      with_env(HttpAdapter::INSECURE_SKIP_TLS_VERIFY_ENV => "1") do
        assert_output(nil, /GEMINABOX_INSECURE_SKIP_TLS_VERIFY is set/) do
          assert_equal OpenSSL::SSL::VERIFY_NONE, @http_adapter.http_client.ssl_config.verify_mode
        end
      end
    end

    def test_other_opt_out_values_keep_verification_on
      %w[0 false no].each do |value|
        with_env(HttpAdapter::INSECURE_SKIP_TLS_VERIFY_ENV => value) do
          mode = HttpClientAdapter.new.http_client.ssl_config.verify_mode

          refute_equal 0, mode & OpenSSL::SSL::VERIFY_PEER, "#{value.inspect} must not disable verification"
        end
      end
    end

    private

    def with_env(vars)
      saved = vars.keys.to_h { |k| [k, ENV.fetch(k, nil)] }
      vars.each { |k, v| ENV[k] = v }
      yield
    ensure
      saved.each { |k, v| ENV[k] = v }
    end

  end
end
