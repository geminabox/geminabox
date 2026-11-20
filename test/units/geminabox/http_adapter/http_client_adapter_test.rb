require_relative '../../../test_helper'
require 'minitest/mock'

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

    def test_trusts_the_gemrc_ssl_ca_cert
      with_rubygems_config(ssl_ca_cert: TestCertificate.ca_file) do
        store = @http_adapter.http_client.ssl_config.cert_store

        assert store.verify(TestCertificate.localhost_cert), "a CA named in gemrc must be trusted"
      end
    end

    def test_does_not_trust_the_test_ca_without_gemrc
      with_env("SSL_CERT_FILE" => nil) do
        with_rubygems_config do
          refute @http_adapter.http_client.ssl_config.cert_store.verify(TestCertificate.localhost_cert)
        end
      end
    end

    def test_presents_the_gemrc_ssl_client_cert
      Tempfile.create(["client", ".pem"]) do |pem|
        pem.write(TestCertificate.localhost_cert.to_pem + TestCertificate.localhost_key.to_pem)
        pem.close
        with_rubygems_config(ssl_client_cert: pem.path) do
          ssl_config = @http_adapter.http_client.ssl_config

          assert_equal TestCertificate.localhost_cert.to_der, ssl_config.client_cert.to_der
          assert_equal TestCertificate.localhost_key.to_der, ssl_config.client_key.to_der
        end
      end
    end

    def test_gemrc_ssl_verify_mode_zero_skips_verification_and_warns
      with_env(HttpAdapter::INSECURE_SKIP_TLS_VERIFY_ENV => nil) do
        with_rubygems_config(ssl_verify_mode: OpenSSL::SSL::VERIFY_NONE) do
          assert_output(nil, /ssl_verify_mode: 0/) do
            assert_equal OpenSSL::SSL::VERIFY_NONE, @http_adapter.http_client.ssl_config.verify_mode
          end
        end
      end
    end

    def test_applies_another_gemrc_ssl_verify_mode
      mode = OpenSSL::SSL::VERIFY_PEER | OpenSSL::SSL::VERIFY_FAIL_IF_NO_PEER_CERT
      with_rubygems_config(ssl_verify_mode: mode) do
        assert_equal mode, @http_adapter.http_client.ssl_config.verify_mode
      end
    end

    private

    RubygemsConfig = Struct.new(:ssl_ca_cert, :ssl_client_cert, :ssl_verify_mode, keyword_init: true)

    def with_rubygems_config(**settings, &block)
      Gem.stub(:configuration, RubygemsConfig.new(**settings), &block)
    end

    def with_env(vars)
      saved = vars.keys.to_h { |k| [k, ENV.fetch(k, nil)] }
      vars.each { |k, v| ENV[k] = v }
      yield
    ensure
      saved.each { |k, v| ENV[k] = v }
    end

  end
end
