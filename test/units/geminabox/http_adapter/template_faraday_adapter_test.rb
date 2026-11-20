require_relative '../../../test_helper'
require 'minitest/mock'

module Geminabox
  class TemplateFaradayAdapterTest < Minitest::Test

    def setup
      @default = 'foo bar'
      @http_adapter = TemplateFaradayAdapter.new
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
    end

    def test_post
      stub_request(:post, "http://example.com/").
        to_return(:status => 200, :body => @default)

      response = @http_adapter.post('http://example.com')
      assert_equal @default, response.body
      assert_equal 200, response.status
    end

    def test_set_auth
      stub_request(:get, "http://example.com/").
         with(:headers => {'Authorization'=>'Basic Zm9vOmJhcg=='}).
         to_return(:status => 200, :body => @default, :headers => {})

      connection = @http_adapter.set_auth('http://example.com', 'foo', 'bar')
      response = connection.get('http://example.com')
      assert_equal @default, response.body
    end

    def test_verifies_tls_certificates_by_default
      with_env(HttpAdapter::INSECURE_SKIP_TLS_VERIFY_ENV => nil) do
        assert_predicate @http_adapter.set_auth('https://example.com').ssl, :verify?
      end
    end

    def test_skips_tls_verification_only_when_opted_out_and_warns
      with_env(HttpAdapter::INSECURE_SKIP_TLS_VERIFY_ENV => "true") do
        assert_output(nil, /GEMINABOX_INSECURE_SKIP_TLS_VERIFY is set/) do
          refute_predicate @http_adapter.set_auth('https://example.com').ssl, :verify?
        end
      end
    end

    def test_trusts_the_gemrc_ssl_ca_cert
      with_rubygems_config(ssl_ca_cert: TestCertificate.ca_file) do
        assert_equal TestCertificate.ca_file, @http_adapter.set_auth('https://example.com').ssl.ca_file
      end
    end

    def test_trusts_a_gemrc_ssl_ca_cert_directory
      Dir.mktmpdir do |dir|
        with_rubygems_config(ssl_ca_cert: dir) do
          ssl = @http_adapter.set_auth('https://example.com').ssl

          assert_equal dir, ssl.ca_path
          assert_nil ssl.ca_file
        end
      end
    end

    def test_presents_the_gemrc_ssl_client_cert
      Tempfile.create(["client", ".pem"]) do |pem|
        pem.write(TestCertificate.localhost_cert.to_pem + TestCertificate.localhost_key.to_pem)
        pem.close
        with_rubygems_config(ssl_client_cert: pem.path) do
          ssl = @http_adapter.set_auth('https://example.com').ssl

          assert_equal TestCertificate.localhost_cert.to_der, ssl.client_cert.to_der
          assert_equal TestCertificate.localhost_key.to_der, ssl.client_key.to_der
        end
      end
    end

    def test_gemrc_ssl_verify_mode_zero_skips_verification_and_warns
      with_env(HttpAdapter::INSECURE_SKIP_TLS_VERIFY_ENV => nil) do
        with_rubygems_config(ssl_verify_mode: OpenSSL::SSL::VERIFY_NONE) do
          assert_output(nil, /ssl_verify_mode: 0/) do
            refute_predicate @http_adapter.set_auth('https://example.com').ssl, :verify?
          end
        end
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
