# frozen_string_literal: true

require_relative 'http_adapter_config_error'

module Geminabox
  class HttpAdapter
    INSECURE_SKIP_TLS_VERIFY_ENV = 'GEMINABOX_INSECURE_SKIP_TLS_VERIFY'

    # Certificates are verified unless the user deliberately opts out, and
    # the opt-out announces itself every time a client is built.
    def verify_tls?
      if %w[1 true].include?(ENV[INSECURE_SKIP_TLS_VERIFY_ENV].to_s.downcase)
        warn_unverified "#{INSECURE_SKIP_TLS_VERIFY_ENV} is set"
        false
      elsif rubygems_ssl_verify_mode == OpenSSL::SSL::VERIFY_NONE
        warn_unverified "ssl_verify_mode: 0 is set in your gemrc"
        false
      else
        true
      end
    end

    # The gemrc TLS settings RubyGems itself uses for gem install and gem push,
    # so a machine that can install from a server can also push to it.
    def rubygems_ssl_verify_mode
      Gem.configuration.ssl_verify_mode
    end

    def rubygems_ssl_ca_cert
      Gem.configuration.ssl_ca_cert
    end

    # Like RubyGems, ssl_client_cert names one PEM holding the certificate and its key.
    def rubygems_ssl_client_cert
      path = Gem.configuration.ssl_client_cert
      return unless path

      pem = File.read(path)
      [OpenSSL::X509::Certificate.new(pem), OpenSSL::PKey.read(pem)]
    end

    def get_content(*args)
      raise HttpAdapterConfigError.new(:get_content, 'the response body')
    end

    def get(*args)
      raise HttpAdapterConfigError.new(:get, 'a response object')
    end

    def post(*args)
      raise HttpAdapterConfigError.new(:post, 'a response object')
    end

    def set_auth(*args)
      raise HttpAdapterConfigError.new(:set_auth, 'true')
    end

    private

    def warn_unverified(reason)
      warn "WARNING: #{reason}, so TLS certificates are not verified. Anyone on the " \
           "network path can read your credentials and the gem you push, and fake a " \
           "successful upload."
    end

  end
end

Dir[File.expand_path('http_adapter/*.rb', File.dirname(__FILE__))].each do |file|
  require file
end