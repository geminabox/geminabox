# frozen_string_literal: true

require 'faraday'

module Geminabox

  class TemplateFaradayAdapter < HttpAdapter

    def get(*args)
      adapter.get(*args)
    end

    def get_content(*args)
      response = adapter.get(*args)
      response.body
    end

    def post(*args)
      adapter.post(*args)
    end

    # Note that this configuration verifies SSL certificates unless
    # GEMINABOX_INSECURE_SKIP_TLS_VERIFY is set.
    # To set up the adapter for your environment see:
    # https://github.com/lostisland/faraday/wiki/Setting-up-SSL-certificates
    def set_auth(uri, username = nil, password = nil)
      connection = Faraday.new url: uri, ssl: ssl_options do |faraday|
        faraday.adapter http_engine
        faraday.proxy(ENV['http_proxy']) if ENV['http_proxy']
      end
      set_username_and_password connection, username, password if username
      connection
    end

    def adapter
      @adapter ||= Faraday.new do |faraday|
        faraday.adapter http_engine
        faraday.proxy(ENV['http_proxy']) if ENV['http_proxy']
      end
    end

    def http_engine
      :net_http # make requests with Net::HTTP
    end

    def options
      lambda {|faraday|
        faraday.adapter http_engine
        faraday.proxy(ENV['http_proxy']) if ENV['http_proxy']
      }
    end

    private

    def ssl_options
      options = { verify: verify_tls? }
      options[:verify_mode] = rubygems_ssl_verify_mode if options[:verify] && rubygems_ssl_verify_mode
      if (ca_cert = rubygems_ssl_ca_cert)
        options[File.directory?(ca_cert) ? :ca_path : :ca_file] = ca_cert
      end
      cert, key = rubygems_ssl_client_cert
      options.merge!(client_cert: cert, client_key: key) if cert
      options
    end

    def set_username_and_password(connection, username, password)
      # Remove this condition when Faraday 1.x dropped (when Ruby 2.5 dropped)
      if Gem::Version.new(Faraday::VERSION) < Gem::Version.new("2.0")
        connection.request :basic_auth, username, password
      else
        # Faraday 2.x
        connection.request :authorization, :basic, username, password
      end
    end

  end
end
