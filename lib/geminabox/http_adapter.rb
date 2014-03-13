require_relative 'http_adapter_config_error'

module Geminabox
  class HttpAdapter

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