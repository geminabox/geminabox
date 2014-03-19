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

    # Note that this configuration turns SSL certificate verification off.
    # To set up the adapter for your environment see:
    # https://github.com/lostisland/faraday/wiki/Setting-up-SSL-certificates
    def set_auth(uri, username = nil, password = nil)
      connection = Faraday.new url: uri, ssl: {verify: false} do |faraday|
        faraday.adapter http_engine
        faraday.proxy(ENV['http_proxy']) if ENV['http_proxy']
      end
      connection.basic_auth username, password if username
      connection
    end

    def adapter
      @adapter ||= Faraday.new do |faraday|
        faraday.adapter http_engine
        faraday.proxy(ENV['http_proxy']) if ENV['http_proxy']
      end
    end

    def http_engine
      :net_http  # make requests with Net::HTTP
    end

    def options
      lambda {|faraday|
        faraday.adapter http_engine
        faraday.proxy(ENV['http_proxy']) if ENV['http_proxy']
      }
    end

  end
end
