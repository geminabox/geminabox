module Geminabox
  class HttpSocketErrorDummy < HttpAdapter

    attr_accessor :default_response

    def get_content(*args)
      raise SocketError.new, default_response
    end

    def get(*args)
      raise SocketError.new, default_response
    end

    def post(*args)
      raise SocketError.new, default_response
    end

    def set_auth(*args)
      raise SocketError.new, default_response
    end

  end
end
