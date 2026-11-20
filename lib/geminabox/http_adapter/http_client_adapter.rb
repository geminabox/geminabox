# frozen_string_literal: true

require 'httpclient'

module Geminabox

  class HttpClientAdapter < HttpAdapter

    def get(*args)
      http_client.get(*args)
    end

    def get_content(*args)
      http_client.get_content(*args)
    end

    def post(*args)
      http_client.post(*args)
    end

    def set_auth(url, username = nil, password = nil)
      http_client.set_auth(url, username, password) if username or password
      http_client.www_auth.basic_auth.challenge(url) # Workaround: https://github.com/nahi/httpclient/issues/63
    end

    def http_client
      @http_client ||= HTTPClient.new(ENV['http_proxy']).tap do |http_client|
        http_client.transparent_gzip_decompression = true
        http_client.keep_alive_timeout = 32 # sec
        configure_tls(http_client.ssl_config)
        http_client.send_timeout = 0
        http_client.receive_timeout = 0
      end
    end

    def http_client=(client)
      @http_client = client
    end

    private

    def configure_tls(ssl_config)
      # httpclient otherwise trusts only its own bundled CA file (from 2015,
      # without Let's Encrypt's root) and ignores SSL_CERT_FILE.
      ssl_config.set_default_paths
      ssl_config.add_trust_ca(rubygems_ssl_ca_cert) if rubygems_ssl_ca_cert
      cert, key = rubygems_ssl_client_cert
      if cert
        ssl_config.client_cert = cert
        ssl_config.client_key = key
      end
      if !verify_tls?
        ssl_config.verify_mode = OpenSSL::SSL::VERIFY_NONE
      elsif rubygems_ssl_verify_mode
        ssl_config.verify_mode = rubygems_ssl_verify_mode
      end
    end
  end
end
