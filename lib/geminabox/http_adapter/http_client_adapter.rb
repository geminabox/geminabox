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
        http_client.ssl_config.verify_mode = OpenSSL::SSL::VERIFY_NONE
        http_client.send_timeout = 0
        http_client.receive_timeout = 0
      end
    end

    def http_client=(client)
      @http_client = client
    end
  end
end
