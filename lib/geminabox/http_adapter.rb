# frozen_string_literal: true

require_relative 'http_adapter_config_error'

module Geminabox
  class HttpAdapter
    INSECURE_SKIP_TLS_VERIFY_ENV = 'GEMINABOX_INSECURE_SKIP_TLS_VERIFY'

    # Certificates are verified unless the user deliberately opts out, and
    # the opt-out announces itself every time a client is built.
    def verify_tls?
      return true unless %w[1 true].include?(ENV[INSECURE_SKIP_TLS_VERIFY_ENV].to_s.downcase)

      warn "WARNING: #{INSECURE_SKIP_TLS_VERIFY_ENV} is set, so TLS certificates are not " \
           "verified. Anyone on the network path can read your credentials and the gem " \
           "you push, and fake a successful upload."
      false
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

  end
end

Dir[File.expand_path('http_adapter/*.rb', File.dirname(__FILE__))].each do |file|
  require file
end